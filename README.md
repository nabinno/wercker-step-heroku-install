# Heroku install step

Install heroku-toolbelt. By default this will create a new ssh-key for
each deploy, see `Using wercker SSH key pair`.

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

# Example

``` yaml
deploy:
    steps:
        - nabinno/heroku-install:
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
- In the `nabinno/heroku-install` step in your `wercker.yml` add the
  `key-name` property with the value you used earlier:

```yaml
deploy:
    steps:
        - nabinno/heroku-install:
            key-name: MY_DEPLOY_KEY
```

In the above example the `MY_DEPLOY_KEY` should match the environment variable
name you used in wercker. Note: you should not prefix it with a dollar sign or
post fix it with `_PRIVATE` or `_PUBLIC`.

# Special thanks

- [wercker/step-heroku-deploy](https://github.com/wercker/step-heroku-deploy)

# License

The MIT License (MIT)

# Changelog

## 3.0.2

- Fork wercker/step-heroku-deploy
