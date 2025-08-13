import axios from "axios";
import tough from "tough-cookie";
import { wrapper } from "axios-cookiejar-support";
import chalk from "chalk";
import { Command, Option } from "commander";
import fs from "fs";
import { input, checkbox, confirm, editor, select } from "@inquirer/prompts";
import Table from "cli-table3";
import ora from "ora";
import figlet from "figlet";

let DEFAULT_CONFIG = {
    "pkg": {
        "abbrev": "my-app"
    },
    "label": "my-app",
    "id": "https://e-editiones.org/apps/my-app",
    "extends": [
        "base10",
        "theme-base10"
    ]
};

// Handle SIGINT gracefully
process.on('SIGINT', () => {
    console.log(chalk.yellow('\nOperation cancelled by user.'));
    process.exit(0);
});

const program = new Command();

// Shared options for all commands
const serverOption = new Option("-s, --server <address>", "Server address").default("http://localhost:8080/exist/apps/jinks");
const userOption = new Option("-u, --user <username>", "Username").default("tei");
const passwordOption = new Option("-p, --password <password>", "Password").default("simple");
const editOption = new Option("-e, --edit", "Use text editor rather than interactive mode to modify configuration.");
const quietOption = new Option("-q, --quiet", "Do not print banner.");

// Hook to run before any command action
program.hook('preAction', async (thisCommand, actionCommand) => {
    const options = actionCommand.opts();

    // Only initialize client if server option is available (commands that need server connection)
    if (options.server) {
        // Store client and configurations in the command context for use in actions
        actionCommand.client = initClient(options);
        actionCommand.allConfigurations = await fetchAvailableConfigurations(actionCommand.client);
    }
});

program.command("list")
    .summary("List installed applications")
    .description("List all (jinks-generated) applications installed on the server.")
    .addOption(serverOption)
    .action(async (options, command) => {
        try {
            listInstalledApplications(command.allConfigurations);
        } catch (error) {
            console.error(error);
        }
    });

program
    .command("create")
    .argument("[abbrev]", "Abbreviated name of the application to create")
    .summary("Create a new application")
    .addOption(serverOption)
    .addOption(userOption)
    .addOption(passwordOption)
    .addOption(editOption)
    .addOption(quietOption)
    .action(async (abbrev, options, command) => {
        printBanner(options);
        try {
            let baseConfig = null;
            if (abbrev) {
                baseConfig = {
                    pkg: { abbrev: abbrev }
                }
            }
            const config = await editOrCreateConfiguration(baseConfig, options, command.allConfigurations, command.client);
            await update(config, options, command.client);
        } catch (error) {
            console.error(error);
        }
    });

program
    .command("edit")
    .argument("[abbrev]", "Application to edit")
    .description("Change an existing application. If no application is provided, you will be prompted to select an installed application.")
    .summary("Change an existing application")
    .addOption(serverOption)
    .addOption(userOption)
    .addOption(passwordOption)
    .addOption(editOption)
    .addOption(quietOption)
    .action(async (abbrev, options, command) => {
        printBanner(options);
        try {
            let config;
            if (abbrev) {
                config = await loadConfigFromApplication(abbrev, command.allConfigurations);
            } else {
                config = await selectInstalledApplication(command.allConfigurations);
            }
            config = await editOrCreateConfiguration(config.config, options, command.allConfigurations, command.client);
            await update(config, options, command.client);
        } catch (error) {
            console.error(error);
        }
    });

program
    .command("update")
    .argument("[abbrev]", "Application to update")
    .description("Update an existing application. If no application is provided, you will be prompted to select an installed application.")
    .summary("Update an existing application")
    .addOption(serverOption)
    .addOption(userOption)
    .addOption(passwordOption)
    .addOption(quietOption)
    .action(async (abbrev, options, command) => {
        printBanner(options);
        try {
            let config;
            if (abbrev) {
                config = await loadConfigFromApplication(abbrev, command.allConfigurations);
            } else {
                config = await selectInstalledApplication(command.allConfigurations);
            }
            await update(config.config, options, command.client);
        } catch (error) {
            console.error(error);
        }
    });

program
    .command("config")
    .argument("[abbrev]", "Application to get configuration for")
    .summary("Get configuration for an application")
    .option("-x, --expand", "Show the expanded configuration")
    .addOption(serverOption)
    .addOption(userOption)
    .addOption(passwordOption)
    .action(async (abbrev, options, command) => {
        try {
            let config = await loadConfigFromApplication(abbrev, command.allConfigurations);
            if (options.expand) {
                config = await expandConfig(config.config, command.client);
            } else {
                config = config.config;
            }
            console.log(JSON.stringify(config, null, 2));
        } catch (error) {
            console.error(error);
        }
    });

program
    .command("run")
    .argument("[abbrev]", "Application to perform action on")
    .argument("[action]", "Name of the action to run, e.g. 'reindex'")
    .summary("Run an action on an installed application")
    .option("-U, --update", "Perform an update of the application before running the action")
    .addOption(serverOption)
    .addOption(userOption)
    .addOption(passwordOption)
    .action(async (abbrev, action, options, command) => {
        try {
            let config;
            if (abbrev) {
                config = await loadConfigFromApplication(abbrev, command.allConfigurations);
            } else {
                config = await selectInstalledApplication(command.allConfigurations);
            }
            if (!action) {
                if (config.actions && config.actions.length > 0) {
                    const actionChoices = config.actions.map(actionItem => ({
                        name: actionItem.description,
                        value: actionItem.name
                    }));

                    action = await select({
                        message: "Select action to perform:",
                        choices: actionChoices
                    });
                } else {
                    console.log(chalk.yellow("No actions available for this application."));
                    return;
                }
            }
            if (options.update) {
                await update(config.config, options, command.client);
            }
            const spinner = ora(`Executing action: ${action}...`).start();
            try {
                // Login first
                await loginUser(command.client, options);

                // Execute the action
                const actionResponse = await command.client.post(`../${config.config.pkg.abbrev}/api/actions/${action}`);

                if (actionResponse.status !== 200) {
                    spinner.fail("Action failed with error: " + actionResponse.status);
                    console.error(actionResponse.data);
                    return;
                }
                spinner.stop();

                const output = actionResponse.data;

                if (output && output.length > 0) {
                    // Table output
                    console.log(chalk.blue("Action response:"));
                    const table = new Table({
                        head: [chalk.bold("Type"), chalk.bold("Message")],
                        colWidths: [15, 50],
                        wordWrap: true
                    });

                    output.forEach((message) => {
                        let typeColored = chalk.blue(message.type.padEnd(15));
                        table.push([typeColored, message.message]);
                    });
                    console.log(table.toString());
                }

                console.log(chalk.green("Action completed successfully!"));
            } catch (error) {
                spinner.fail("Action execution failed");
                console.error(error);
            }
        } catch (error) {
            console.error(error);
        }
    });

program.parse();

function printBanner(options) {
    if (!options.quiet) {
        const banner = figlet.textSync("Jinks", { font: "Standard" });
        console.log(chalk.blue(banner));
    }
}

function initClient(options) {
    const cookieJar = new tough.CookieJar();
    return wrapper(
        axios.create({
            baseURL: options.server,
            jar: cookieJar,
            withCredentials: true,
        })
    );
}

// Helper function to login user
async function loginUser(client, options) {
    const params = new URLSearchParams();
    params.append("user", options.user);
    params.append("password", options.password);

    const loginResponse = await client.post("/api/login", params, {
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
    });

    if (loginResponse.status !== 200) {
        throw new Error(`Login failed: ${loginResponse.status} ${loginResponse.data}`);
    }
}

// Helper function to fetch available configurations
async function fetchAvailableConfigurations(client) {
    const spinner = ora("Fetching available configurations...").start();
    try {
        const configResponse = await client.get("/api/configurations");
        spinner.stop();
        return configResponse.data;
    } catch (error) {
        spinner.fail(`Could not fetch configurations: ${error.message}\n`);
        return null;
    }
}

// Helper function to load configuration from JSON file
function loadConfigFromFile(filePath) {
    try {
        const fileContent = fs.readFileSync(filePath, "utf8");
        return JSON.parse(fileContent);
    } catch (error) {
        console.error("Error reading or parsing JSON file:", error.message);
        process.exit(1);
    }
}

// Helper function to list installed applications
function listInstalledApplications(allConfigurations) {
    console.log(chalk.blue('Installed applications:\n'));
    const configs = allConfigurations
        .filter(
            (item) => item.type === "installed",
        )
        .map((item) => item.config.pkg.abbrev);
    console.log(configs.join("\n"));
}

async function expandConfig(config, client) {
    const spinner = ora("Expanding configuration...").start();
    try {
        const expandedConfig = await client.post("/api/expand", config);
        spinner.stop();
        return expandedConfig.data;
    } catch (error) {
        spinner.fail(`Could not expand configuration: ${error.message}\n`);
        return null;
    }
}

// Helper function to load configuration from application
async function loadConfigFromApplication(appOption, allConfigurations) {
    if (!appOption) {
        try {
            return await selectInstalledApplication(allConfigurations);
        } catch (error) {
            if (error.name === 'ExitPromptError' || error.message.includes('SIGINT')) {
                console.log(chalk.yellow('\nOperation cancelled by user.'));
                process.exit(0);
            } else {
                console.error(chalk.red('Error during configuration collection:'), error.message);
                process.exit(1);
            }
        }
    } else {
        // Load configuration from existing application
        const config = allConfigurations.find(
            (item) => item.config.pkg.abbrev === appOption,
        );
        if (!config) {
            console.error(chalk.red(`Application ${appOption} not found.`));
            process.exit(1);
        }
        return config;
    }
}

// Helper function to edit and save configuration
async function editOrCreateConfiguration(config, options, allConfigurations, client) {
    if (options.edit) {
        const edited = await editor({
            message: "Edit configuration:",
            default: JSON.stringify(config || DEFAULT_CONFIG, null, 2),
            waitForUseInput: false
        });
        config = JSON.parse(edited);
    } else {
        // If no file is provided, use interactive prompts
        try {
            config = await collectConfigInteractively(config, allConfigurations, client);
        } catch (error) {
            if (error.name === 'ExitPromptError' || error.message.includes('SIGINT')) {
                console.log(chalk.yellow('\nOperation cancelled by user.'));
                process.exit(0);
            } else {
                console.error(chalk.red('Error during configuration collection:'), error.message);
                process.exit(1);
            }
        }
    }

    console.log("\n" + chalk.blue("Using configuration:"));
    console.log(JSON.stringify(config, null, 2));

    return config;
}

async function selectInstalledApplication(allConfigurations) {
    const installed = allConfigurations
        .filter(
            (item) => item.type === "installed",
        )
        .sort((a, b) => a.config.label.localeCompare(b.config.label))
        .map((item) => ({
            name: chalk.bold(item.config.label) +
                (item.config.description ? ` – ${item.config.description}` : ''),
            value: item,
        }));
    return await select({
        message: "Select installed application:",
        choices: installed,
    });
}

// Function to handle interactive prompts
async function collectConfigInteractively(initialConfig = {}, configurations, client) {
    console.log(
        chalk.blue("Entering interactive mode...\n"),
    );

    try {
        const abbrev = await input({
            message: "Enter abbreviation:",
            default: initialConfig?.pkg?.abbrev || "my app",
        });

        const label = await input({
            message: "Enter label:",
            default: initialConfig?.label || abbrev,
        });

        const id = await input({
            message: "Enter unique identifier (URL):",
            default: initialConfig?.id || `https://e-editiones.org/apps/${abbrev}`,
        });

        // Filter profiles and create checkbox options
        const profileOptions = configurations
            .filter(
                (item) =>
                    item.type === "profile" &&
                    item.config.type !== "theme" &&
                    item.config.type !== "base",
            )
            .sort((a, b) => a.config.label.localeCompare(b.config.label))
            .map((profile) => ({
                name: `${chalk.bold(profile.profile)} – ${profile.config.label}`,
                value: profile.profile,
                description: profile.description || "",
                checked: initialConfig?.extends?.includes(profile.profile),
            }));

        let selectedProfiles = [];
        if (profileOptions.length > 0) {
            selectedProfiles = await checkbox({
                message: "Select features:",
                choices: profileOptions,
                pageSize: 10,
                loop: false
            });
        }

        // Sort selected profiles by order attribute
        selectedProfiles.sort((a, b) => {
            const profileA = configurations.find(config => config.profile === a);
            const profileB = configurations.find(config => config.profile === b);

            const orderA = profileA?.config?.order ?? Number.MAX_SAFE_INTEGER;
            const orderB = profileB?.config?.order ?? Number.MAX_SAFE_INTEGER;

            return orderA - orderB;
        });

        const newConfig = {
            overwrite: "default",
            pkg: { abbrev: abbrev },
            label: label,
            id: id,
            extends: ["base10", "theme-base10", ...selectedProfiles],
        };

        return newConfig;
    } catch (error) {
        // Re-throw the error to be handled by the caller
        throw error;
    }
}

async function update(config, options, client, resolve = []) {
    const requestBody = {
        config: config,
        resolve,
    };

    // 1. Login to get the cookie
    try {
        await loginUser(client, options);
    } catch (error) {
        console.error(error.message);
        return;
    }

    let spinner = ora("Starting generator ...").start();

    // 2. Use the cookie for the generator request
    const generatorResponse = await client.post(
        "/api/generator?overwrite=default",
        requestBody,
    );

    if (generatorResponse.status !== 200) {
        spinner.fail("Generator failed with error: " + generatorResponse.status);

        console.error(generatorResponse.data);
        return;
    }
    spinner.stop();

    const output = generatorResponse.data;

    if (output.messages.length > 0) {
        // Table output
        console.log(chalk.blue("Generator response:"));
        const table = new Table({
            head: [chalk.bold("Type"), chalk.bold("Path"), chalk.bold("Source")],
            colWidths: [12, 40, 40],
            wordWrap: true,
        });

        output.messages.forEach((message) => {
            let typeColored;
            switch (message.type) {
                case "update":
                    typeColored = chalk.green(message.type.padEnd(10));
                    break;
                case "warning":
                    typeColored = chalk.yellow(message.type.padEnd(10));
                    break;
                case "conflict":
                    typeColored = chalk.red(message.type.padEnd(10));
                    break;
                default:
                    typeColored = message.type.padEnd(10);
            }
            const source = (message.source || "").replace(
                "/db/apps/jinks/profiles/",
                "",
            );
            table.push([typeColored, message.path || "", source]);
        });
        console.log(table.toString());
    }

    if (output.nextStep && output.nextStep.action === "DEPLOY") {
        spinner = ora("Deploying ...").start();
        const deployResponse = await client.post(
            `/api/generator/${config.pkg.abbrev}/deploy`,
        );
        if (deployResponse.status !== 200) {
            spinner.fail("Deploy failed with code " + deployResponse.status + ": " + deployResponse.data);
            console.error(
                "Deploy failed:",
                deployResponse.status,
                deployResponse.data,
            );
            return;
        }
        spinner.stop();
        console.log(chalk.green("Done!"));
    }

    const conflicts = output.messages.filter(message => message.type === "conflict");
    resolveConflicts(conflicts, config, options, client);
}

async function resolveConflicts(conflicts, config, options, client) {
    if (conflicts.length === 0) {
        return;
    }

    const resolve = await confirm({
        message: "Conflicts detected. Resolve conflicts?",
    });
    if (!resolve) {
        return;
    }

    const choices = conflicts.map(conflict => ({
        name: conflict.path,
        value: conflict.path
    }));

    const resolved = await checkbox({
        message: "Select conflicts to resolve:",
        choices: choices
    });

    console.log(chalk.blue("Re-running ..."));
    update(config, options, client, resolved);
}
