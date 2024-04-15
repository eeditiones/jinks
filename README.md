# Application Manager for TEI Publisher

Replaces the custom app generator in earlier versions of TEI Publisher. The idea is to create a more powerful tool for creating, updating and maintaining a custom application. The generator

* can not only create new custom applications, but also reconfigure them at a later time
* uses a hierarchy of application *profiles* targeted at specific use cases. A profile can extend or build upon other profiles.
* detects local changes to files and leaves them untouched
* comes with its own [templating language](templating.md), which can also process plain-text files (XQuery, CSS etc.)

## Profiles

Profiles are blueprints for applications targeted at a specific use case like a monography, correspondance edition, dictionary etc. Each profile has a subcollection under `profiles` and must contain at least one configuration file, `config.json`, which defines all the variables to be used in templated files.

### `config.json`

The `config.json` must define a property named `id` with a unique, valid URI. This is the URI under which eXist's package manager will later install the application package.

It may also specify a property `extends`, which should contain the name of a profile to extend. TEI Publisher apps will in general extend the *base* profile, which installs the required files shared by all custom TP applications.

The extension process works as follows:

1. the generator creates a merged configuration, assembled from the configurations of all profiles in the extension hierarchy
2. it calls the *write action* on every profile in sequence

### `setup.xql`

The profile may also include an XQuery module called `setup.xql`. If present, the generator will inspect the functions defined in this module, searching for functions with the annotations `%generator:prepare` and `%generator:write`. They represent different stages in the generation process:

* `%generator:prepare`: receives the merged configuration map - including all changes applied by previous calls to prepare - and may return a modified map. Use this to compute and set custom properties needed by your profile.
* `%generator:write`: performs the actual installation.

`%generator:write` receives the merged configuration as parameter `$context`. It should use the functions of the `cpy` module to copy or write files into the target collection, given by the property `$context?target`. The source, i.e. the collection containing the profile's source, is available in `$context?source`.

If no `setup.xql` is present or no `%generator:write` function is defined, the default action is to call

```xquery
cpy:copy-collection($context)
```

which boils down to copying everything contained in the profile's source folder into the target destination.

### Templates

The `cpy:copy-collection` function will automatically process any file containing `.tpl` in its name as a template, which means the contents will be expanded through the [templating module](templating.md) using the current *configuration*.