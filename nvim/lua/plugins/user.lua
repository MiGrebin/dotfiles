-- You can also add or configure plugins by creating files in this `plugins/` folder
-- PLEASE REMOVE THE EXAMPLES YOU HAVE NO INTEREST IN BEFORE ENABLING THIS FILE
-- Here are some examples:

---@type LazySpec
return {

  -- == Examples of Adding Plugins ==

  "andweeb/presence.nvim",
  {
    "ray-x/lsp_signature.nvim",
    event = "BufRead",
    config = function() require("lsp_signature").setup() end,
  },

  -- == Examples of Overriding Plugins ==

  -- customize dashboard options
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = table.concat({
            " █████  ███████ ████████ ██████   ██████ ",
            "██   ██ ██         ██    ██   ██ ██    ██",
            "███████ ███████    ██    ██████  ██    ██",
            "██   ██      ██    ██    ██   ██ ██    ██",
            "██   ██ ███████    ██    ██   ██  ██████ ",
            "",
            "███    ██ ██    ██ ██ ███    ███",
            "████   ██ ██    ██ ██ ████  ████",
            "██ ██  ██ ██    ██ ██ ██ ████ ██",
            "██  ██ ██  ██  ██  ██ ██  ██  ██",
            "██   ████   ████   ██ ██      ██",
          }, "\n"),
        },
      },
    },
  },

  -- You can disable default plugins as follows:
  { "max397574/better-escape.nvim", enabled = false },

  -- You can also easily customize additional setup of plugins that is outside of the plugin's setup call
  {
    "L3MON4D3/LuaSnip",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.luasnip"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom luasnip configuration such as filetype extend or custom snippets
      local luasnip = require "luasnip"
      luasnip.filetype_extend("javascript", { "javascriptreact" })
    end,
  },

  {
    "windwp/nvim-autopairs",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom autopairs configuration such as custom rules
      local npairs = require "nvim-autopairs"
      local Rule = require "nvim-autopairs.rule"
      local cond = require "nvim-autopairs.conds"
      npairs.add_rules(
        {
          Rule("$", "$", { "tex", "latex" })
            -- don't add a pair if the next character is %
            :with_pair(cond.not_after_regex "%%")
            -- don't add a pair if  the previous character is xxx
            :with_pair(
              cond.not_before_regex("xxx", 3)
            )
            -- don't move right when repeat character
            :with_move(cond.none())
            -- don't delete if the next character is xx
            :with_del(cond.not_after_regex "xx")
            -- disable adding a newline when you press <cr>
            :with_cr(cond.none()),
        },
        -- disable for .vim files, but it work for another filetypes
        Rule("a", "a", "-vim")
      )
    end,
  },
  {
    "kiyoon/nvim-tree-remote.nvim",
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      local image_exts = { png = true, jpg = true, jpeg = true, gif = true, bmp = true, webp = true, svg = true, ico = true, tiff = true }
      local video_exts = { mov = true, mp4 = true, m4v = true, avi = true }
      local function open_node(state)
        local node = state.tree:get_node()
        if node.type == "file" then
          local path = node:get_id()
          local ext = path:match("%.(%w+)$")
          if ext and image_exts[ext:lower()] then
            vim.fn.system('open -a Preview "' .. path .. '"')
          elseif ext and video_exts[ext:lower()] then
            vim.fn.system('open -a "QuickTime Player" "' .. path .. '"')
          else
            vim.fn.system("tmux display-popup -xC -yC -w80% -h80% -E 'nvim \"" .. path .. "\"'")
          end
        else
          require("neo-tree.sources.filesystem.commands").toggle_node(state)
        end
      end
      local function context_menu(state)
        local node = state.tree:get_node()
        if node.type ~= "file" then return end
        local path = node:get_id()
        local ext = path:match("%.(%w+)$") or ""
        local actions = {
          { label = "Open in tmux popup", action = function() vim.fn.system("tmux display-popup -xC -yC -w80% -h80% -E 'nvim \"" .. path .. "\"'") end },
          { label = "Copy path", action = function() vim.fn.setreg("+", path) vim.notify("Copied: " .. path) end },
        }
        if ext:lower() == "html" then
          table.insert(actions, 1, { label = "Open in browser", action = function() vim.fn.system('open "' .. path .. '"') end })
        end
        if image_exts[ext:lower()] then
          table.insert(actions, 1, { label = "Open in Preview", action = function() vim.fn.system('open -a Preview "' .. path .. '"') end })
        end
        if video_exts[ext:lower()] then
          table.insert(actions, 1, { label = "Open in QuickTime", action = function() vim.fn.system('open -a "QuickTime Player" "' .. path .. '"') end })
        end
        vim.ui.select(
          vim.tbl_map(function(a) return a.label end, actions),
          { prompt = node.name },
          function(_, idx) if idx then actions[idx].action() end end
        )
      end
      opts.window = opts.window or {}
      opts.window.mappings = vim.tbl_deep_extend("force", opts.window.mappings or {}, {
        ["<cr>"] = { open_node, desc = "Open file in tmux popup / Preview for images" },
        ["<2-LeftMouse>"] = { open_node, desc = "Double-click open" },
        ["<RightMouse>"] = { context_menu, desc = "Context menu" },
        ["X"] = { context_menu, desc = "Context menu" },
      })
      return opts
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        basedpyright = {
          settings = {
            basedpyright = {
              analysis = {
                typeCheckingMode = "basic",
              },
            },
          },
        },
      },
    },
  },
}
