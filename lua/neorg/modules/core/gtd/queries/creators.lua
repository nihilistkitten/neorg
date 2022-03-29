local module = neorg.modules.extend("core.gtd.queries.creators")

---@class core.gtd.queries
module.public = {
    --- Creates a new project/task (depending of `type`) from the `node` table and insert it in `bufnr` at `location`
    --- supported `string`: project|task
    --- @param type string
    --- @param node core.gtd.queries.task|core.gtd.queries.project
    --- @param location table
    --- @param opts table|nil opts
    ---   - opts.no_save(boolean)    if true, don't save the buffer
    create = function(type, node, location, opts)
        vim.validate({
            type = {
                type,
                function(t)
                    return vim.tbl_contains({ "project", "task" }, t)
                end,
                "project|task",
            },
            node = { node, "table" },
            location = { location, "table" },
            opts = { opts, "table", true },
        })

        opts = opts or {}

        if not node.content then
            log.error("No node content provided")
            return
        end

        if not node.internal or not node.internal.bufnr then
            log.error("Missing internal information")
        end

        local inserter = {}
        local bufnr = node.internal.bufnr

        local indendation = string.rep(" ", location[2])
        local prefix = type == "project" and "* " or "- [ ] "
        table.insert(inserter, indendation .. prefix .. node.content)

        local temp_buf = module.required["core.queries.native"].get_temp_buf(bufnr)
        vim.api.nvim_buf_set_lines(temp_buf, location[1], location[1], false, inserter)

        local nodes = module.public.get(type .. "s", { bufnr = bufnr })
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        local inserted_line = location[1] + #inserter
        for _, n in pairs(nodes) do
            local line = ts_utils.get_node_range(n[1]) + 1

            if line == inserted_line then
                node.internal.node = n[1]
            end
        end

        if node.internal.node == nil then
            log.error("Error in inserting new content")
        end

        ---@type core.gtd.base.config
        local config = neorg.modules.get_module_config("core.gtd.base")
        local syntax = config.syntax

        module.private.insert_tag({ node.internal.node, bufnr }, node.contexts, syntax.context)
        module.private.insert_tag({ node.internal.node, bufnr }, node["time.start"], syntax.start)
        module.private.insert_tag({ node.internal.node, bufnr }, node["time.due"], syntax.due)
        module.private.insert_tag({ node.internal.node, bufnr }, node["waiting.for"], syntax.waiting)

        if not opts.no_save then
            module.required["core.queries.native"].apply_temp_changes(bufnr)
        end
    end,

    --- Returns the end of the `project`
    --- If the project has blank lines at the end, will not take them ino account
    --- @param node userdata
    --- @param bufnr number
    --- @return number
    get_end_project = function(node, bufnr)
        vim.validate({
            node = { node, "userdata" },
            bufnr = { bufnr, "number" },
        })
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()
        local sr, sc = ts_utils.get_node_range(node)

        local tree = {
            { query = { "all", "heading2" } },
            { query = { "all", "heading3" } },
            { query = { "all", "heading4" } },
            { query = { "all", "heading5" } },
            { query = { "all", "heading6" } },
        }
        local nodes = module.required["core.queries.native"].query_from_tree(node, tree, bufnr)

        if nodes and not vim.tbl_isempty(nodes) then
            return { sr + 1, sc + 2 }
        end

        -- Do not count blank lines at end of a project
        local lines = ts_utils.get_node_text(node, bufnr)
        local blank_lines = 0
        for i = #lines, 1, -1 do
            local value = lines[i]
            value = string.gsub(value, "%s*", "")

            if value == "" then
                blank_lines = blank_lines + 1
            else
                break
            end
        end

        return { sr + #lines - blank_lines, sc + 2 }
    end,

    --- Returns the end of the document content position of a `file`
    --- @param bufnr string
    --- @return number, number, boolean
    get_end_document_content = function(bufnr)
        vim.validate({
            file = { bufnr, "number" },
        })

        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        local tree = {
            { query = { "first", "document_content" } },
        }
        local document = module.required["core.queries.native"].query_nodes_from_buf(tree, bufnr)[1]

        local end_row
        local projectAtEnd = false

        -- There is no content in the document
        if not document then
            local temp_buf = module.required["core.queries.native"].get_temp_buf(bufnr)
            end_row = vim.api.nvim_buf_line_count(temp_buf)
        else
            -- Check if last child is a project
            local nb_childs = document[1]:child_count()
            local last_child = document[1]:child(nb_childs - 1)
            if last_child:type() == "heading1" then
                projectAtEnd = true
            end

            _, _, end_row, _ = ts_utils.get_node_range(document[1])
            -- Because TS is 0 based
            end_row = end_row + 1
        end

        return end_row, projectAtEnd
    end,
}

module.private = {
    --- Insert the tag above a `type`
    --- @param node table #Must be { node, bufnr }
    --- @param content? string|table
    --- @param prefix string
    --- @return boolean #Whether inserting succeeded (if so, save the file)
    insert_tag = function(node, content, prefix, opts)
        vim.validate({
            node = { node, "table" },
            content = {
                content,
                function(c)
                    return vim.tbl_contains({ "string", "table", "nil" }, type(c))
                end,
                "string|table",
            },
            prefix = { prefix, "string" },
            opts = { opts, "table", true },
        })

        opts = opts or {}
        local inserter = {}

        -- Creates the content to be inserted
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()
        local node_line, node_col, _, _ = ts_utils.get_node_range(node[1])
        local inserted_prefix = string.rep(" ", node_col) .. prefix
        module.private.insert_content(inserter, content, inserted_prefix)

        local parent_tag_set = module.required["core.queries.native"].find_parent_node(node, "carryover_tag_set")

        local queries = module.required["core.queries.native"]
        local temp_buf = queries.get_temp_buf(node[2])

        if #parent_tag_set == 0 then
            -- No tag created, i will insert the tag just before the node or at specific line
            if opts.line then
                node_line = opts.line
            end
            vim.api.nvim_buf_set_lines(temp_buf, node_line, node_line, false, inserter)
            return true
        else
            -- Gets the last tag in the found tag_set and append after it
            local tags_number = parent_tag_set[1]:child_count()
            local last_tag = parent_tag_set[1]:child(tags_number - 1)
            local start_row, _, _, _ = ts_utils.get_node_range(last_tag)

            vim.api.nvim_buf_set_lines(temp_buf, start_row, start_row, false, inserter)
            return true
        end
    end,
}

return module
