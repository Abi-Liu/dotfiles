return {
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"hrsh7th/nvim-cmp",
			"hrsh7th/cmp-nvim-lsp",
			"j-hui/fidget.nvim", -- nice LSP status UI
			"folke/neodev.nvim", -- better Lua dev (Neovim API)
		},
		config = function()
			-- UI helpers
			require("fidget").setup({})
			require("neodev").setup({})

			-- Mason (LSP/DAP/Linters installer)
			require("mason").setup({
				ui = { border = "rounded" },
			})

			local lspconfig = require("lspconfig")
			local mason_lspconfig = require("mason-lspconfig")

			-- -------- Capabilities (incl. cmp + multiline semantic tokens) ----------
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			capabilities.textDocument.semanticTokens = { multilineTokenSupport = true }
			pcall(function()
				capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)
			end)

			-- --------------------------- on_attach ----------------------------------
			local on_attach = function(client, bufnr)
				local nmap = function(lhs, rhs, desc)
					vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = "LSP: " .. desc })
				end

				client.server_capabilities.documentFormattingProvider = false
				client.server_capabilities.documentRangeFormattingProvider = false

				nmap("gd", vim.lsp.buf.definition, "Goto Definition")
				nmap("gD", vim.lsp.buf.declaration, "Goto Declaration")
				nmap("gr", vim.lsp.buf.references, "References")
				nmap("gi", vim.lsp.buf.implementation, "Goto Implementation")
				nmap("K", vim.lsp.buf.hover, "Hover")
				nmap("<leader>rn", vim.lsp.buf.rename, "Rename Symbol")
				nmap("<leader>ca", vim.lsp.buf.code_action, "Code Action")
				nmap("[d", vim.diagnostic.goto_prev, "Prev Diagnostic")
				nmap("]d", vim.diagnostic.goto_next, "Next Diagnostic")
				nmap("<leader>e", vim.diagnostic.open_float, "Line Diagnostics")
				-- nmap("<leader>fm", function() 
				-- 	require(conform).format({async = true, lsp_fallback = true})
				-- end , "Format Buffer")

				-- Inlay hints if the server supports them (Neovim 0.10+)
				if client.server_capabilities.inlayHintProvider then
					vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
				end
			end

			-- ------------------------- Diagnostics look -----------------------------
			vim.diagnostic.config({
				virtual_text = { prefix = "●", spacing = 2 },
				severity_sort = true,
				float = { border = "rounded", source = "if_many" },
				underline = true,
				update_in_insert = false,
			})

			-- Nice signs
			local signs = { Error = "", Warn = "", Hint = "", Info = "" }
			for type, icon in pairs(signs) do
				local hl = "DiagnosticSign" .. type
				vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
			end

			-- --------------------- Servers & their settings -------------------------
			-- Add/remove servers in this table and Mason will auto-install them.
			local servers = {
				-- Lua (Neovim)
				lua_ls = {
					settings = {
						Lua = {
							completion = { callSnippet = "Replace" },
							diagnostics = { globals = { "vim" } },
							workspace = {
								checkThirdParty = false,
								library = {
									"${3rd}/luv/library",
									vim.fn.expand("$VIMRUNTIME/lua"),
									vim.fn.stdpath("config") .. "/lua",
								},
							},
							telemetry = { enable = false },
						},
					},
				},

				-- Web
				tsserver = {},
				html = {},
				cssls = {},
				tailwindcss = {},

				-- Python
				pyright = {},
				ruff = {}, -- optional linter server (complements pyright)

				-- Rust / Go
				-- rust_analyzer = {},
				gopls = {},

				-- Java
				jdtls = {},

				-- Markup / Data
				jsonls = {},
				yamlls = {},
				marksman = {}, -- Markdown
				taplo = {}, -- TOML

				-- Shell
				bashls = {},
			}

			-- Make Mason ensure these are installed
			mason_lspconfig.setup({
				ensure_installed = (function(tbl)
					local keys = {}
					for name, _ in pairs(tbl) do table.insert(keys, name) end
					table.insert(keys, "java-test")
					table.insert(keys, "java-debug-adapter")
					table.insert(keys, "google-java-format")
					return keys
				end)(servers),
				automatic_installation = true,
			})

			-- Optional: per-server deep tweaks
			local per_server_overrides = {
				ts_ls = function(opts)
					-- Example tweaks:
					opts.single_file_support = false
					opts.init_options = {
						preferences = {
							includeInlayParameterNameHints = "all",
							includeInlayEnumMemberValueHints = true,
							includeInlayFunctionLikeReturnTypeHints = true,
							includeInlayVariableTypeHints = true,
						},
					}
					return opts
				end,
				jsonls = function(opts)
					-- Fetch schemas from schemastore (if you use it)
					local ok, schemastore = pcall(require, "schemastore")
					if ok then
						opts.settings = opts.settings or {}
						opts.settings.json = opts.settings.json or {}
						opts.settings.json.schemas = schemastore.json.schemas()
						opts.settings.json.validate = { enable = true }
					end
					return opts
				end,
				yamlls = function(opts)
					opts.settings = {
						yaml = {
							keyOrdering = false,
							format = { enable = true },
							validate = true,
						},
					}
					return opts
				end,
			}

			-- --------------- Wire defaults into every server via handlers -----------
			mason_lspconfig.setup_handlers({
				function(server_name)
					local opts = servers[server_name] or {}
					opts.capabilities = vim.tbl_deep_extend("force", {}, capabilities, opts.capabilities or {})
					opts.on_attach = on_attach

					if per_server_overrides[server_name] then
						opts = per_server_overrides[server_name](opts)
					end

					lspconfig[server_name].setup(opts)
				end,
			})

			-- -------- Optional: format on save toggle (global) ----------------------
			vim.g.autoformat = true
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = vim.api.nvim_create_augroup("LspFormatOnSave", { clear = true }),
				callback = function(args)
					if not vim.g.autoformat then return end
					local buf = args.buf
					local clients = vim.lsp.get_active_clients({ bufnr = buf })
					for _, c in ipairs(clients) do
						if c.server_capabilities.documentFormattingProvider then
							vim.lsp.buf.format({ bufnr = buf, timeout_ms = 1000 })
							return
						end
					end
				end,
			})
		end,
	},
}
