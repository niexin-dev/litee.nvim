local M = {}

local float_win = nil

-- 本地实现：去掉头尾的空行，替代 vim.lsp.util.trim_empty_lines()
local function trim_empty_lines(lines)
    local start_idx = 1
    local end_idx = #lines

    -- 去掉开头空行
    while start_idx <= end_idx and lines[start_idx]:match("^%s*$") do
        start_idx = start_idx + 1
    end

    -- 去掉结尾空行
    while end_idx >= start_idx and lines[end_idx]:match("^%s*$") do
        end_idx = end_idx - 1
    end

    local new = {}
    for i = start_idx, end_idx do
        new[#new + 1] = lines[i]
    end
    return new
end

-- close_hover_popups closes the created popup window
-- if it exists.
function M.close_hover_popup()
    if float_win ~= nil and vim.api.nvim_win_is_valid(float_win) then
        vim.api.nvim_win_close(float_win, true)
        float_win = nil
    end
end

-- hover_handle shows hover information for a symbol in a calltree
-- ui window.
--
-- modified from neovim runtime/lua/vim/lsp/handlers.lua
-- function conforms to client LSP handler signature.
function M.hover_handler(_, result, ctx, config)
    M.close_hover_popup()

    config = config or {}
    config.focus_id = ctx.method

    if not (result and result.contents) then
        -- return { 'No information available' }
        return
    end

    -- 从 LSP 结果生成 markdown 行
    local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
    lines = trim_empty_lines(lines) -- 使用我们自己的实现

    if vim.tbl_isempty(lines) then
        -- return { 'No information available' }
        return
    end

    -- create buffer for popup
    local buf = vim.api.nvim_create_buf(false, false)
    if buf == 0 then
        vim.api.nvim_err_writeln("details_popup: could not create details buffer")
        return
    end

    vim.api.nvim_buf_set_option(buf, "bufhidden", "delete")
    vim.api.nvim_buf_set_option(buf, "syntax", "markdown")
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

    -- 之前这里调用的是 vim.lsp.util.stylize_markdown(buf, lines, {})
    -- 该 API 已弃用，我们改成简单方案：
    -- 只用 markdown filetype + treesitter 高亮（如果有安装 markdown parser）
    pcall(vim.treesitter.start, buf, "markdown")

    -- 计算浮窗宽度
    local width = 20
    for _, line in ipairs(lines) do
        local line_width = vim.fn.strdisplaywidth(line)
        if line_width > width then
            width = line_width
        end
    end

    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, #lines, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)

    local popup_conf = vim.lsp.util.make_floating_popup_options(
        width,
        #lines,
        {
            border = "rounded",
            focusable = false,
            zindex = 99,
        }
    )

    float_win = vim.api.nvim_open_win(buf, false, popup_conf)

    return float_win
end

return M

