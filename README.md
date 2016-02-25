# Heroku deployment step

Deploy your code to Heroku. This step requires that you deploy to a Heroku
deploy target. By default this will create a new ssh-key for each deploy, see
`Using wercker SSH key pair`.

# Dependencies

These dependencies are required for this step. Make sure they are installed, and
available in `$PATH` before running this step:

- git
- mktemp

The following dependencies are only required when using temporary keys (see:
`Using wercker SSH key pair`):

- curl
- ssh-keygen


# What's new

- Remove some changing of directories.
- Mark `source_dir` as deprecated. In a future version this will be replaced
  with `cwd`, currently they however are not compatible.

# Options

* `key` (required) API key used to create a new SSH key. Alternatively you can
  use the global environment variable `$HEROKU_KEY`.
* `user` (required) User used to create a new SSH key. Alternatively you can use
  the global environment variable `$HEROKU_USER`.
* `app-name` (required) The name of the app that you are deploying.
  Alternatively you can use `$HEROKU_APP_NAME`.
* `key-name` (optional) Specify the name of the key that should be used for this
  deployment. If left empty, a temporary key will be created for the deployment.
* `retry` (optional) When a deploy to Heroku fails, a new deploy is
  automatically performed after 5 seconds. If you want to disable this behavior,
  set `retry` to `false`.
* `run` (optional) Run a command on heroku after the code is deployed
  succesfully. This option can be used to migrate the database for example.
* `install-toolbelt` (optional). If set to 'true', the toolbelt will be
  installed. Note: specifying a run command will also install the toolbelt.
* `keep-repository` (optional) This will allow a user to keep the original
  history of the repository, speeding up deployment. **Important:** changes made
  during the build will not be deployed. Also keep in mind that deploying an
  already up to date repo will not result in an application restart. Use the
  `run` parameter to forcibly reload to achieve this. This feature is considered
  beta, expect issues. If you find one, please contact us.

# Example

``` yaml
deploy:
    steps:
        - heroku-deploy:
            key-name: MY_DEPLOY_KEY
```

# Using wercker SSH key pair

To push to Heroku we need to have an ssh key. We can dynamically generate a key,
add the key to your repository and then remove it, during each build. But this
results in an e-mail from Heroku on each deploy.

To prevent this you can generate a private/public key pair on wercker and
manually add the public key to Heroku.

- Generate a new key in wercker in the `Key management` section
  (`application` - `settings`).
- Copy the public key and add it on Heroku to the `SSH Keys section` section
  (`account`).
- In wercker edit the Heroku deploy target to which you would like to deploy,
  and add an environment variable:
    - Give the environment variable a name (remember this name, you will need it
      in the last step).
    - Select `SSH Key pair` as the type and select the key pair which you
      created earlier.
- In the `heroku-deploy` step in your `wercker.yml` add the `key-name` property
  with the value you used earlier:

```yaml
deploy:
    steps:
        - heroku-deploy:
            key-name: MY_DEPLOY_KEY
```

In the above example the `MY_DEPLOY_KEY` should match the environment variable
name you used in wercker. Note: you should not prefix it with a dollar sign or
post fix it with `_PRIVATE` or `_PUBLIC`.

# Special thanks

- [wernerb](https://app.wercker.com/#wernerb) for fixing submodule support and
  allowing the repository to be reused.

# License

The MIT License (MIT)

# Changelog

## 3.1.0

- Add support for GIT_SSH_COMMAND

## 3.0.1

- Fix sending randomly generating SSH keys to Heroku

## 3.0.0

- Refactor

## 2.2.1

- fixed: ssh: connect to host git.heroku.com port 22: Connection timed out

## 2.2.0

- Remove some changing of directories
- Mark `source_dir` as deprecated. In a future version this will be replaced
  with `cwd`, currently they however are not compatible.

## 2.1.0

- Check if API key is still valid.
- Check if app exists on Heroku.
- Suppress output of curl.

## 2.0.2

- fix: allow step to be run multiple times in a single deploy

## 2.0.1

- add install_toolbelt option

## 2.0.0

- Major refactor:
- Only install toolbelt if needed (currently only required for running a
  command).
- Fix security issue, where the host key was ignored.
- run.sh now uses functions.

## 1.0.14

- Add `keep-repository` parameter.

## 1.0.11

- Fix pushing submodules to heroku by flattening submodules if found.

## 1.0.9

- Make sure git-core is installed when heroku toolbelt.

## 1.0.7

* Fix bugs related to the `run` parameter.

## 1.0.5

* Update README, to clearify using a SSH Key pair.

## 1.0.4

* Fixed release that also works on ruby based boxes (always installs ruby 1.9.1)

## 1.0.1

* fix for apt-get bug: deb files are now included [broken]

## 1.0.0

* Bug fixes

## 0.0.9-dev

* Adds `run` option.

## 0.0.8

* Retry on failure.

## 0.0.7

* Only call `heroku keys:remove` if a ephemeral key was used
  (wercker/step-heroku-deploy#2).
* Update README.

## 0.0.6

* Fix wrong option check.

## 0.0.4

* Added validation to `key-name` option.

## 0.0.3

* Added `key-name` option.

## 0.0.2

* Initial release.
