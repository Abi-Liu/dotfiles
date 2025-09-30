return {
  "mfussenegger/nvim-jdtls",
  ft = { "java" },
  dependencies = {
    "williamboman/mason.nvim",
    "mfussenegger/nvim-dap",
  },
  config = function()
    local jdtls = require("jdtls")
    local home = vim.env.HOME
    local project = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
    local workspace = home .. "/.local/share/eclipse/" .. project

    -- Try to locate lombok.jar (env var, Homebrew, or a fallback path)
    local lombok = vim.env.LOMBOK_JAR
      or (vim.fn.executable("brew") == 1 and vim.fn.trim(vim.fn.system("brew --prefix lombok")) .. "/share/java/lombok.jar")
      or (home .. "/.local/share/java/lombok.jar")

    local capabilities = vim.lsp.protocol.make_client_capabilities()
    local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
    if ok then capabilities = cmp_lsp.default_capabilities(capabilities) end
    capabilities.textDocument.semanticTokens = { multilineTokenSupport = true }

    -- Mason jdtls binary
    local jdtls_bin = vim.fn.stdpath("data") .. "/mason/bin/jdtls"

    -- Build cmd: include Lombok as a JVM arg so JDT sees generated code
    local cmd = {
      jdtls_bin,
      "--jvm-arg=-javaagent:" .. lombok,
      "--jvm-arg=-Xbootclasspath/a:" .. lombok,
      "-data", workspace,
    }

    jdtls.start_or_attach({
      cmd = cmd,
      root_dir = require("jdtls.setup").find_root({ ".git", "mvnw", "gradlew", "pom.xml" }),
      capabilities = capabilities,
      -- (optional) your usual settings...
      settings = {
        java = {
          configuration = {
            -- set your JDKs if needed
            -- runtimes = { { name = "JavaSE-17", path = "/path/to/jdk-17" }, },
          },
        },
      },
      -- (optional) if you also use java-test / java-debug-adapter:
      init_options = {
        bundles = (function()
          local bundles = {}
          local mason = vim.fn.stdpath("data") .. "/mason/packages"
          local dbg = vim.fn.glob(mason .. "/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar")
          if dbg ~= "" then table.insert(bundles, dbg) end
          for _, jar in ipairs(vim.split(vim.fn.glob(mason .. "/java-test/extension/server/*.jar"), "\n")) do
            if jar ~= "" then table.insert(bundles, jar) end
          end
          return bundles
        end)(),
      },
    })
  end,
}

