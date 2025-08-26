import axios from "axios";
import tough from "tough-cookie";
import { wrapper } from "axios-cookiejar-support";
import chalk from "chalk";
import { Command, Option } from "commander";
import fs from "fs";
import path from "path";
import { input, checkbox, confirm, editor, select, Separator } from "@inquirer/prompts";
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
const reinstallOption = new Option("-r, --reinstall", "Fully reinstall application, overwriting existing files.");
const forceOption = new Option("-f, --force", "Ignore last modified date and check every file for changes.");
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
            const config = await createConfiguration(baseConfig, options, command.allConfigurations, command.client);
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
    .addOption(reinstallOption)
    .addOption(forceOption)
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
    .addOption(reinstallOption)
    .addOption(forceOption)
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

program.command("create-profile")
    .argument("[abbrev]", "Name of the profile to create")
    .summary("Create a new profile")
    .addOption(serverOption)
    .addOption(userOption)
    .addOption(passwordOption)
    .option("-o, --out <file>", "Directory to save the profile configuration to")
    .action(async (abbrev, options, command) => {
        printBanner(options);
        let baseConfig = null;
        if (abbrev) {
            baseConfig = {
                pkg: { abbrev: abbrev }
            }
        }
        try {
            await createOrEditProfile(baseConfig, options.out, command.allConfigurations);
        } catch (error) {
            console.error(error);
        }
    });

program.command("edit-profile")
    .argument("<dir>", "Directory containing the profile configuration")
    .summary("Edit an existing profile")
    .addOption(serverOption)
    .addOption(userOption)
    .addOption(passwordOption)
    .action(async (dir, options, command) => {
        printBanner(options);
        const config = loadConfigFromFile(path.join(dir, "config.json"));
        try {
            await createOrEditProfile(config, dir, command.allConfigurations);
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
        process.exit(1);
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

async function createConfiguration(config, options, allConfigurations, client) {
    return await editOrCreateConfiguration(config, options, allConfigurations, client, true);
}

// Helper function to edit and save configuration
async function editOrCreateConfiguration(config, options, allConfigurations, client, create = false) {
    if (options.edit) {
        const edited = await editor({
            message: "Edit configuration:",
            default: JSON.stringify(config || DEFAULT_CONFIG, null, 2),
            waitForUseInput: false,
            postfix: ".json"
        });
        config = JSON.parse(edited);
    } else {
        // If no file is provided, use interactive prompts
        try {
            config = await collectConfigInteractively(config, allConfigurations, config?.extends);
        } catch (error) {
            if (error.name === 'ExitPromptError' || error.message.includes('SIGINT')) {
                console.log(chalk.yellow('\nOperation cancelled by user.'));
                process.exit(0);
            } else {
                console.error(error);
                console.error(chalk.red('Error during configuration collection:'), error.message);
                process.exit(1);
            }
        }
    }

    console.log("\n" + chalk.blue("Using configuration:"));
    console.log(JSON.stringify(config, null, 2));

    if (create) {
        const shouldEdit = await confirm({
            message: "Would you like to edit this configuration?",
            default: false
        });

        if (shouldEdit) {
            const edited = await editor({
                message: "Edit configuration:",
                default: JSON.stringify(config, null, 2),
                waitForUseInput: false,
                postfix: ".json"
            });
            config = JSON.parse(edited);

            console.log("\n" + chalk.blue("Updated configuration:"));
            console.log(JSON.stringify(config, null, 2));
        }
    }
    return config;
}

async function createOrEditProfile(config, outDir, configurations) {
    const profileType = await select({
        message: "Select profile type:",
        choices: [
            {
                name: "Blueprint - Base configuration for an application",
                value: "blueprint"
            },
            {
                name: "Feature - Reusable functionality module",
                value: "feature"
            },
            {
                name: "Theme - Styling and appearance configuration",
                value: "theme"
            }
        ],
        default: config?.type || "blueprint"
    });
    
    try {
        const newConfig = await collectConfigInteractively(config, configurations, config?.depends);
        const depends = newConfig.extends;
        delete newConfig.extends;
        const profileConfig = {
            ...newConfig,
            type: profileType,
            version: newConfig.version || "1.0.0",
            depends,
            skipSource: ["repo.xml", "expath-pkg.xml", "build.xml"]
        }

        try {
            fs.mkdirSync(outDir, { recursive: true });
            const configPath = path.join(outDir, 'config.json');
            fs.writeFileSync(configPath, JSON.stringify(profileConfig, null, 2));

            const expathPath = path.join(outDir, 'expath-pkg.xml');
            const expath = `<?xml version="1.0" encoding="UTF-8" ?>
<package xmlns="http://expath.org/ns/pkg" name="${profileConfig.id}" abbrev="${profileConfig.pkg.abbrev}" version="${profileConfig.version}" spec="1.0">
    <title>${profileConfig.label}</title>
    <dependency processor="http://exist-db.org" semver-min="6.2.0" />
    <dependency package="http://e-editiones.org/roaster" semver="1"/>
</package>`;
            fs.writeFileSync(expathPath, expath);

            const repoPath = path.join(outDir, 'repo.xml');
            const repo = `<?xml version="1.0" encoding="UTF-8" ?>
<meta xmlns="http://exist-db.org/xquery/repo">
    <description>${profileConfig.label}</description>
    <author>Wolfgang Meier</author>
    <website>https://github.com/eeditiones/tei-publisher-lib.git</website>
    <status>stable</status>
    <license>GPLv3</license>
    <copyright>true</copyright>
    <type>application</type>
    <target>${profileConfig.pkg.abbrev}</target>
    <permissions user="tei" group="tei" password="simple" mode="rw-rw-r--" />
</meta>`;
            fs.writeFileSync(repoPath, repo);

            const buildPath = path.join(outDir, 'build.xml');
            const build = `<?xml version="1.0" encoding="UTF-8"?>
<project default="all" name="${profileConfig.label}">
    <xmlproperty file="expath-pkg.xml"/>
    <property name="project.version" value="\${package(version)}"/>
    <property name="project.app" value="\${package(abbrev)}"/>
    <property name="build.dir" value="build"/>
    <target name="all" depends="xar"/>
    <target name="rebuild" depends="clean,all"/>
    <target name="clean">
        <delete dir="\${build}"/>
    </target>
    <target name="xar">
        <mkdir dir="\${build.dir}"/>
        <zip basedir="." destfile="\${build.dir}/\${project.app}-\${project.version}.xar" excludes="\${build.dir}/*"/>
    </target>
</project>`;
            fs.writeFileSync(buildPath, build);

            console.log(chalk.green(`Profile configuration saved to ${chalk.bold(configPath)}`));
        } catch (error) {
            console.error(chalk.red(`Failed to create profile directory: ${error.message}`));
            process.exit(1);
        }
    } catch (error) {
        if (error.name === 'ExitPromptError' || error.message.includes('SIGINT')) {
            console.log(chalk.yellow('\nOperation cancelled by user.'));
            process.exit(0);
        } else {
            console.error(error);
            console.error(chalk.red('Error during configuration collection:'), error.message);
            process.exit(1);
        }
    }
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
async function collectConfigInteractively(initialConfig = {}, configurations, dependencies) {
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

        const blueprintOptions = configurations
            .filter((item) => item.type === "profile" && item.config.type === "blueprint")
            .sort((a, b) => a.config.label.localeCompare(b.config.label))
            .map((blueprint) => ({
                name: `${chalk.bold(blueprint.profile)} – ${blueprint.config.label}`,
                value: blueprint.profile,
                description: blueprint.description || "",
                checked: dependencies?.includes(blueprint.profile),
            }));

        // Filter profiles and create checkbox options
        const profileOptions = configurations
            .filter(
                (item) =>
                    item.type === "profile" &&
                    !["theme", "base", "blueprint", "disabled"].includes(item.config.type)
            )
            .sort((a, b) => a.config.label.localeCompare(b.config.label))
            .map((profile) => ({
                name: `${chalk.bold(profile.profile)} – ${profile.config.label}`,
                value: profile.profile,
                description: profile.description || "",
                checked: dependencies?.includes(profile.profile),
            }));

        const selectOptions = [new Separator('Blueprints'), ...blueprintOptions, new Separator('Features'), ...profileOptions];
        let selectedProfiles = [];
        if (profileOptions.length > 0) {
            selectedProfiles = await checkbox({
                message: "Select features to include:",
                choices: selectOptions,
                pageSize: 10,
                loop: false,
                theme: {
                    icon: {
                        unchecked: "[ ]",
                        checked: "[x]"
                    }
                }
            });
        }

        // Check for missing dependencies
        const baseProfiles = ["base10", "theme-base10"];
        const currentExtends = [...baseProfiles, ...selectedProfiles];
        const missingDependencies = [];
        const missingProfiles = [];

        for (const profileName of selectedProfiles) {
            const profileConfig = configurations.find(config => config.profile === profileName);
            if (profileConfig?.config?.depends) {
                for (const dependency of profileConfig.config.depends) {
                    if (!currentExtends.includes(dependency)) {
                        // Check if the dependency profile exists
                        const dependencyConfig = configurations.find(config => config.profile === dependency);
                        if (dependencyConfig) {
                            missingDependencies.push({
                                profile: profileName,
                                dependency: dependency,
                                label: profileConfig.config.label,
                                dependencyLabel: dependencyConfig.config.label
                            });
                        } else {
                            missingProfiles.push({
                                profile: profileName,
                                dependency: dependency,
                                label: profileConfig.config.label
                            });
                        }
                    }
                }
            }
        }

        // Show warnings for missing profile configurations
        if (missingProfiles.length > 0) {
            console.log(chalk.red("\n❌ Some dependencies reference profiles that don't exist:"));
            for (const item of missingProfiles) {
                console.log(chalk.red(`   • ${item.label} (${item.profile}) depends on missing profile: ${item.dependency}`));
            }
            console.log(chalk.yellow("   These dependencies will be ignored."));
        }

        // Ask user if they want to add missing dependencies
        if (missingDependencies.length > 0) {
            console.log(chalk.yellow("\n⚠️  Some selected profiles have dependencies that are not included yet:"));

            for (const item of missingDependencies) {
                console.log(chalk.yellow(`   • ${item.label} (${item.profile}) depends on: ${item.dependencyLabel} (${item.dependency})`));
            }

            const addDependencies = await confirm({
                message: "Do you want to add these dependencies automatically?",
                default: true
            });

            if (addDependencies) {
                for (const item of missingDependencies) {
                    if (!currentExtends.includes(item.dependency)) {
                        currentExtends.push(item.dependency);
                        console.log(chalk.green(`   ✓ Added dependency: ${item.dependencyLabel} (${item.dependency})`));
                    }
                }
            }
        }

        // Sort all profiles (including dependencies) by order attribute
        const profilesToSort = currentExtends.filter(profile => profile !== "base10" && profile !== "theme-base10");
        profilesToSort.sort((a, b) => {
            const profileA = configurations.find(config => config.profile === a);
            const profileB = configurations.find(config => config.profile === b);

            const orderA = profileA?.config?.order ?? Number.MAX_SAFE_INTEGER;
            const orderB = profileB?.config?.order ?? Number.MAX_SAFE_INTEGER;

            return orderA - orderB;
        });

        // Reconstruct currentExtends with proper ordering
        currentExtends.splice(2); // Remove all profiles after base profiles
        currentExtends.push(...profilesToSort);

        const newConfig = {
            ...initialConfig,
            overwrite: "default",
            pkg: { abbrev: abbrev },
            label: label,
            id: id,
            extends: currentExtends,
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
        `/api/generator?overwrite=${options.reinstall ? "all" : (options.force ? "force" : "default")}`,
        requestBody
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

    if (options.reinstall || (output.nextStep && output.nextStep.action === "DEPLOY")) {
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
    } else if (output.messages.length === 0) {
        console.log(chalk.green("No changes detected."));
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
