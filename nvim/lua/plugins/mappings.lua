return {
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      mappings = {
        n = {
          -- Run Python file with Cmd+R (or Ctrl+R on non-Mac)
          ["<D-r>"] = {
            function()
              -- Save the file first
              vim.cmd "write"
              -- Get the current file path
              local file = vim.fn.expand "%:p"
              -- Run python on the current file in a terminal
              vim.cmd("split | terminal python3 " .. file)
            end,
            desc = "Run Python file",
          },
        },
      },
    },
  },
}
