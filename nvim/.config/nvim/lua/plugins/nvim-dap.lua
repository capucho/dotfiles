return {
  "mfussenegger/nvim-dap",
  optional = true,
  dependencies = {
    {
      "mason-org/mason.nvim",
      opts = function(_, opts)
        opts.ensure_installed = opts.ensure_installed or {}
        table.insert(opts.ensure_installed, "js-debug-adapter")
      end,
    },
  },
  opts = function()
    local dap = require("dap")
    local mason_registry = require("mason-registry")

    if not dap.adapters["pwa-node"] then
      local ok, js_pkg = pcall(mason_registry.get_package, "js-debug-adapter")
      if ok and js_pkg:is_installed() then
        require("dap").adapters["pwa-node"] = {
          type = "server",
          host = "localhost",
          port = "${port}",
          executable = {
            command = "node",
            args = {
              js_pkg:get_install_path() .. "/js-debug/src/dapDebugServer.js",
              "${port}",
            },
          },
        }
      else
        vim.notify("nvim-dap: js-debug-adapter not installed. Run :MasonInstall js-debug-adapter", vim.log.levels.WARN)
      end
    end

    -- TypeScript/JavaScript DAP configuration with ESM support
    for _, language in ipairs({ "typescript", "javascript", "typescriptreact", "javascriptreact" }) do
      if not dap.configurations[language] then
        dap.configurations[language] = {
          {
            type = "pwa-node",
            request = "launch",
            name = "Launch file (ESM via tsx)",
            runtimeExecutable = "npx",
            runtimeArgs = { "tsx", "${file}" },
            cwd = "${workspaceFolder}",
            skipFiles = { "<node_internals>/**" },
            resolveSourceMapLocations = {
              "${workspaceFolder}/**",
              "!**/node_modules/**",
            },
            sourceMaps = true,
            outputCapture = "std",
          },
          {
            type = "pwa-node",
            request = "launch",
            name = "Launch file (ESM via node)",
            program = "${file}",
            cwd = "${workspaceFolder}",
            runtimeExecutable = "node",
            runtimeArgs = { "--loader", "ts-node/esm" },
            env = {
              NODE_OPTIONS = "--experimental-loader ts-node/esm",
            },
            skipFiles = { "<node_internals>/**" },
            resolveSourceMapLocations = {
              "${workspaceFolder}/**",
              "!**/node_modules/**",
            },
            sourceMaps = true,
            outputCapture = "std",
          },
          {
            type = "pwa-node",
            request = "launch",
            name = "Launch file (CommonJS)",
            program = "${file}",
            cwd = "${workspaceFolder}",
            skipFiles = { "<node_internals>/**" },
            sourceMaps = true,
            outputCapture = "std",
          },
          {
            type = "pwa-node",
            request = "attach",
            name = "Attach",
            processId = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
            skipFiles = { "<node_internals>/**" },
            sourceMaps = true,
          },
        }
      end
    end
  end,
}
