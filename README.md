<img src="resources/images/logo.png" width="360">

# jinks - Application Manager for TEI Publisher

Jinks' purpose is to aid in creation, maintenance and updating of custom TEI Publisher applications.

This tool:

* can **create** new custom applications, 
* **adjust** the configuration at **any time** later
* automate the **upgrade** of the custom app to the newest Jinks/TEI Publisher version, tracking and respecting custom changes in the app

**NB** Jinks replaces and extends the app generator in TEI Publisher 9 and earlier.

## Jinks templates

Jinks uses a modern [templating engine](https://github.com/eeditiones/jinks-templates), providing a unified, syntax for all templating tasks in the TEI Publisher ecosystem. It can process XML as well as other file types (plain-text, XQuery CSS, etc.) supporting block-based template inheritance and XPath, among other features.

## Profiles: Blueprints, themes and features

The core concept of jinks is the *profile*. Jinks provides a set of *profiles* targeted at specific use cases, which can be assembled as necessary.

A profile can build upon, i.e. extend and import other profiles. It can also be very minimalistic, contributing only a singular feature.

Conceptually we distinguish **three** different **types of profiles**:

A *blueprint* is a complete template for an application targeted at a specific use case like a monograph, correspondence edition, dictionary, etc. An application generated from a blueprint is fully functional.

A *feature* is a functional sub-profile to be imported into another profile. It adds specific functionality, e.g., docker configuration, additional visualizations, pages, etc.

A *theme* is a customization of a base profile, changing mainly the look and feel, e.g., modify images, fonts, or colors according to a corporate identity.

All profiles are implemented following the same basic pattern. Each profile is a subcollection under `profiles` and must contain at least one configuration file, `config.json`, which defines all the profile-related variables to be used in templated files.

### `config.json`

The `config.json` must define a property named `id` with a unique, valid URI. This is the URI under which eXist's package manager will later install the application package.

It may also specify a property `extends`, which should contain the names of one or more profiles to extend. TEI Publisher apps will in general extend the *base* profile, which installs the required files shared by all custom TP applications.

The extension process works as follows:

1. jinks creates a merged configuration, assembled from the configurations of all profiles in the extension hierarchy
2. it calls the *write action* on every profile in sequence

### `setup.xql`

The profile may also include an XQuery module called `setup.xql`. If present, jinks will inspect the functions defined in this module, searching for functions with the annotations `%generator:prepare` and `%generator:write`. They represent different stages in the generation process:

* `%generator:prepare`: receives the merged configuration map - including all changes applied by previous calls to prepare - and may return a modified map. Use this to compute and set custom properties needed by your profile
* `%generator:write`: performs the actual installation
* `%generator:after-write` is called after the application has been updated (or installed if it was not generated before)

`%generator:write` receives the merged configuration as parameter `$context`. It should use the functions of the `cpy` module to copy or write files into the target collection, given by the property `$context?target`. The source, i.e. the collection containing the profile's source, is available in `$context?source`.

`%generator:after-write` receives the target collection in which the application is installed as first parameter, the current context as second.  

If no `setup.xql` is present or no `%generator:write` function is defined, the default action is to call

```xquery
cpy:copy-collection($context)
```

which boils down to copying everything contained in the profile's source folder into the target destination.

### Templates

The `cpy:copy-collection` function will automatically process any file containing `.tpl` in its name as a template, which means the contents will be expanded through the [templating module](https://github.com/eeditiones/jinks-templates) using the current *configuration*.

## Usage

For the time being, we provide a basic web interface for jinks, which allows you to select a profile, see its full configuration (with inherited profile configurations merged together), and generate a custom app.

Convenient configuration forms will be added later once the basic profiles reach a more stable state.

## API endpoint and XQuery module

After installing the jinks application package via the dashboard, open http://localhost:8080/exist/apps/tei-publisher-jinks/api.html in your browser. The `/api/generator/{profile}` provides the main API entry point.

The main entry point into jinks is provided by the module [`modules/generator.xql`](modules/generator.xql), which exposes the function:

```xquery
declare function generator:process($profile as xs:string, $settings as map(*)?, $config as map(*)?)
```

where the parameters are as follows:

* `$profile`: the name of the profile to apply
* `$settings`: general settings to control the generator
* `$config`: user-supplied configuration, which will overwrite the config.json in the profile

The function will return a map with the properties: `conflicts` and `config`, where the first contains a list of resources which were modified by the user since the last run and were therefore not overwritten (see below). `config` shows the merged configuration used during the run.

### Updates and Conflicts

When creating a new custom application, the profile (and its sub-profiles) will copy or write all required files into a temporary collection, package it up as an eXist application xar, and finally install it into eXist.

Once the application has been installed, users may call the manager again with a modified configuration. The manager detects that an app with the same URI does already exist and by default applies the changes to the existing app collection only. The `overwrite` property, which can be passed in the `settings` parameter to `generator:process`, determines how updates are handled:

* *default*: target files are not overwritten unless there's a new incoming version with different content
* *update*: the target file will always be overwritten by the incoming version even if the content has not changed
* *all*: the entire application is rebuilt from the profile and reinstalled into eXist

Unless `overwrite=all`, jinks will **never** overwrite files which have been changed by the user since they were installed from the profile. To track changes, an SHA-256 key is computed for every file and stored in the `.generator.json` file in the target app.

Conflicting files will be reported by the `generator:process` function.

## Note on AI

**Jinks** and **TEI Publisher** are built for speed, interoperability, and sustainability. Experienced developers routinely build features faster than an AI agent using our framework. However, we know AI tools are a reality for many workflows. To save your time and precious resources, and prevent common pitfalls, we have curated and tested specific agentic skills for key tasks, located under `AGENTS.md` and in the `skills` subdirectories.

**We strongly recommend** using AI agents to work in small, incremental steps, ensuring a competent human review at every stage of the entire process. We also offer support packages to start you on the right track or assist with the review. This way you are benefitting from the wealth of community-wisdom and contribute back to it.

## Shared Ecosystem and Sustainability 

Open source is a shared ecosystem that requires active maintenance to survive. We believe in and hope for **fair reciprocity**. Therefore, we strongly request a **financial contribution** proportionate to the value this framework adds to your project, business, or workflow.

* **For short-term Academic, Research or other Non-Commercial Projects:** We suggest a one-time donation to e-editiones or the purchase of a small support package.
* **For larger, long-term Projects and Institutions:** If you run a long-running project, or represent an institution managing multiple projects, we kindly ask for an institutional membership in e-editiones combined with a larger support package, or a direct financial contribution toward the development and maintenance of the framework or a specific feature.
* **For Grants & Funding Proposals:** If you are planning a new grant-funded project or research proposal, we are happy to partner with you. Including us as a project partner or budget line item is an excellent way to fund the development of new features and custom enhancements that your specific project requires.

## Acknowledgements

Jinks is a community-driven open-source project coordinated by **e-editiones**, relying on individuals who generously contribute their time to its design, development, maintenance, dissemination, and support.

Jinks has been directly funded and supported by a number of research and cultural heritage organizations. We would like to particularly acknowledge substantial contributions from the following institutions:

### [Jagiellonian Digital Platform](https://labedyt.dhlab.uj.edu.pl/)

![dhlab](./resources/images/dhlab.svg)

### [Office of the Historian, Shared Knowledge Services, Bureau of Administration, United States Department of State](https://history.state.gov/)

### [Tadeusz Manteuffel Institute of History, Polish Academy of Sciences](https://ihpan.edu.pl/en/)

![ihpan](./resources/images/ihpan.svg)