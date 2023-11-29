local utils = require("harpoon2.test.utils")
local harpoon = require("harpoon2")

local eq = assert.are.same

local be = utils.before_each(os.tmpname())

describe("harpoon", function()
    before_each(function()
        be()
        harpoon = require("harpoon2")
    end)

    it("when we change buffers we update the row and column", function()
        local file_name = "/tmp/harpoon-test"
        local row = 1
        local col = 0
        local target_buf = utils.create_file(file_name, {
            "foo",
            "bar",
            "baz",
            "qux",
        }, row, col)

        local list = harpoon:list():append()
        local other_buf = utils.create_file("other-file", {
            "foo",
            "bar",
            "baz",
            "qux",
        }, row, col)

        vim.api.nvim_set_current_buf(target_buf)
        vim.api.nvim_win_set_cursor(0, { row + 1, col })
        vim.api.nvim_set_current_buf(other_buf)

        local expected = {
            { value = file_name, context = { row = row + 1, col = col } },
        }

        eq(expected, list.items)
    end)

    it("full harpoon add sync cycle", function()
        local file_name = "/tmp/harpoon-test"
        local row = 3
        local col = 1
        local default_list_name = harpoon:info().default_list_name
        utils.create_file(file_name, {
            "foo",
            "bar",
            "baz",
            "qux",
        }, row, col)

        local list = harpoon:list()
        list:append()
        harpoon:sync()

        eq(harpoon:dump(), {
            testies = {
                [default_list_name] = list:encode(),
            },
        })
    end)

    it("prepend/append double add", function()
        local default_list_name = harpoon:info().default_list_name
        local file_name_1 = "/tmp/harpoon-test"
        local row_1 = 3
        local col_1 = 1

        local file_name_2 = "/tmp/harpoon-test-2"
        local row_2 = 1
        local col_2 = 2

        local contents = { "foo", "bar", "baz", "qux" }

        local bufnr_1 = utils.create_file(file_name_1, contents, row_1, col_1)
        local list = harpoon:list():append()

        utils.create_file(file_name_2, contents, row_2, col_2)
        harpoon:list():prepend()

        harpoon:sync()

        eq(harpoon:dump(), {
            testies = {
                [default_list_name] = list:encode(),
            },
        })

        eq(list.items, {
            { value = file_name_2, context = { row = row_2, col = col_2 } },
            { value = file_name_1, context = { row = row_1, col = col_1 } },
        })

        harpoon:list():append()
        vim.api.nvim_set_current_buf(bufnr_1)
        harpoon:list():prepend()

        eq(list.items, {
            { value = file_name_2, context = { row = row_2, col = col_2 } },
            { value = file_name_1, context = { row = row_1, col = col_1 } },
        })
    end)

    it("ui - display resolve", function()
        harpoon:setup({
            default = {
                display = function(item)
                    -- split string on /
                    local parts = vim.split(item.value, "/")
                    return parts[#parts]
                end,
            },
        })

        local file_names = {
            "/tmp/harpoon-test-1",
            "/tmp/harpoon-test-2",
            "/tmp/harpoon-test-3",
            "/tmp/harpoon-test-4",
        }

        local contents = { "foo", "bar", "baz", "qux" }

        local bufnrs = {}
        local list = harpoon:list()
        for _, v in ipairs(file_names) do
            table.insert(bufnrs, utils.create_file(v, contents))
            harpoon:list():append()
        end

        local displayed = list:display()
        eq(displayed, {
            "harpoon-test-1",
            "harpoon-test-2",
            "harpoon-test-3",
            "harpoon-test-4",
        })

        table.remove(displayed, 3)
        table.remove(displayed, 2)

        list:resolve_displayed(displayed)

        eq(list.items, {
            { value = file_names[1], context = { row = 4, col = 2 } },
            { value = file_names[4], context = { row = 4, col = 2 } },
        })
    end)

    it("ui - display resolve", function()
        local file_names = {
            "/tmp/harpoon-test-1",
            "/tmp/harpoon-test-2",
            "/tmp/harpoon-test-3",
            "/tmp/harpoon-test-4",
        }

        local contents = { "foo", "bar", "baz", "qux" }

        local bufnrs = {}
        local list = harpoon:list()
        for _, v in ipairs(file_names) do
            table.insert(bufnrs, utils.create_file(v, contents))
            harpoon:list():append()
        end

        local displayed = list:display()
        eq(displayed, {
            "/tmp/harpoon-test-1",
            "/tmp/harpoon-test-2",
            "/tmp/harpoon-test-3",
            "/tmp/harpoon-test-4",
        })

        table.remove(displayed, 3)
        table.remove(displayed, 2)

        table.insert(displayed, "/tmp/harpoon-test-other-file-1")
        table.insert(displayed, "/tmp/harpoon-test-other-file-2")

        list:resolve_displayed(displayed)

        eq({
            { value = file_names[1], context = { row = 4, col = 2 } },
            { value = file_names[4], context = { row = 4, col = 2 } },
            {
                value = "/tmp/harpoon-test-other-file-1",
                context = { row = 1, col = 0 },
            },
            {
                value = "/tmp/harpoon-test-other-file-2",
                context = { row = 1, col = 0 },
            },
        }, list.items)

        table.remove(displayed, 3)
        table.insert(displayed, "/tmp/harpoon-test-4")
        list:resolve_displayed(displayed)

        eq({
            { value = file_names[1], context = { row = 4, col = 2 } },
            { value = file_names[4], context = { row = 4, col = 2 } },
            {
                value = "/tmp/harpoon-test-other-file-2",
                context = { row = 1, col = 0 },
            },
        }, list.items)
    end)
end)
