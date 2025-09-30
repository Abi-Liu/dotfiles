return {
  -- HARPOON v2
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim", -- ensure Telescope is available
    },
    config = function()
      local harpoon = require("harpoon")

      -- helper: open Harpoon list in Telescope (ivy theme)
      local function toggle_telescope(hlist)
        -- require Telescope lazily (only when this runs)
        local ok_conf, tconf = pcall(function() return require("telescope.config").values end)
        local ok_themes, themes = pcall(function() return require("telescope.themes") end)
        if not (ok_conf and ok_themes) then
          vim.notify("Telescope not available", vim.log.levels.WARN)
          return
        end

        local items = {}
        for _, item in ipairs(hlist.items) do
          table.insert(items, item.value)
        end

        local opts = themes.get_ivy({
          prompt_title = "Working List", -- (was misspelled as 'promt_title')
          previewer = true,
        })

        require("telescope.pickers").new(opts, {
          finder = require("telescope.finders").new_table({ results = items }),
          previewer = tconf.file_previewer(opts),
          sorter = tconf.generic_sorter(opts),
        }):find()
      end

      -- keymaps
      vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end, { desc = "Harpoon: Add file" })
      vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end,
        { desc = "Harpoon: Toggle menu" })
      vim.keymap.set("n", "<leader>fl", function() toggle_telescope(harpoon:list()) end,
        { desc = "Harpoon: Telescope list" })
      vim.keymap.set("n", "<C-p>", function() harpoon:list():prev() end, { desc = "Harpoon: Prev" })
      vim.keymap.set("n", "<C-n>", function() harpoon:list():next() end, { desc = "Harpoon: Next" })
    end
  },

  -- TELESCOPE
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local actions = require("telescope.actions")
      require("telescope").setup({
        defaults = {
          mappings = {
            i = {
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-j>"] = actions.move_selection_next,
              ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
            },
          },
        },
      })

      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fo", builtin.oldfiles, { desc = "Recent files" })
      vim.keymap.set("n", "<leader>fq", builtin.quickfix, { desc = "Quickfix" })
      vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })

      vim.keymap.set("n", "<leader>fg", function()
        builtin.grep_string({ search = vim.fn.input("Grep > ") })
      end, { desc = "Grep string" })

      vim.keymap.set("n", "<leader>fc", function()
        local filename_without_ext = vim.fn.expand("%:t:r")
        builtin.grep_string({ search = filename_without_ext })
      end, { desc = "Grep current filename" })

      vim.keymap.set("n", "<leader>fs", function()
        builtin.grep_string({})
      end, { desc = "Grep word under cursor" })

      vim.keymap.set("n", "<leader>fi", function()
        builtin.find_files({ cwd = vim.fn.expand("~/.config/nvim/") })
      end, { desc = "Find in nvim config" })
    end,
  },
}
