<img src="resources/images/logo.png" width="360">

# jinks - Application Manager for TEI Publisher

Replaces the custom app generator in earlier versions of TEI Publisher. The idea is to create a more powerful tool for creating, updating and maintaining a custom application. This tool:

* can not only create new custom applications, but also reconfigure them at a later time
* uses a hierarchy of application *profiles* targeted at specific use cases. A profile can extend or build upon other profiles. It can be modular, i.e., contribute only one feature
* detects local changes to files and leaves them untouched
* comes with its own [templating module](https://github.com/eeditiones/jinks-templates), which can also process plain-text files (XQuery, CSS, etc.)

## Profiles: Blueprints, themes and features

The core concept of jinks is the *profile*. Profiles can extend and import each other. We distinguish three different kinds of profiles:

A *blueprint* is a complete template for an application targeted at a specific use case like a monograph, correspondence edition, dictionary, etc. An application generated from a blueprint is fully functional.

A *feature* is a functional sub-profile to be imported into another profile. It adds specific functionality, e.g., docker configuration, additional visualizations, pages, etc.

A *theme* is a customization of a base profile, changing mainly the look and feel, e.g., modify images, fonts, or colors according to a corporate identity.

Each profile has a subcollection under `profiles` and must contain at least one configuration file, `config.json`, which defines all the variables to be used in templated files.

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


## Acknowledgements

Jinks has been funded and supported by a number of research and cultural heritage organizations, as well as through individual contributions.

We would like to particularly acknowledge substantial support from the following institutions:

### [Jagiellonian Digital Platform](https://labedyt.dhlab.uj.edu.pl/)

![dhlab](./resources/images/dhlab.svg)

### [Office of the Historian, Shared Knowledge Services, Bureau of Administration, United States Department of State](https://history.state.gov/)

### [Tadeusz Manteuffel Institute of History, Polish Academy of Sciences](https://ihpan.edu.pl/en/)

![ihpan](./resources/images/ihpan.svg)

