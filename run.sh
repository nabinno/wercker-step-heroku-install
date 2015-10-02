#!/bin/bash
set -e;

main() {
    local exit_code_push=0;
    local exit_code_run=0;
    local gitssh_path;
    local ssh_key_path;

    gitssh_path="$(mktemp)";
    ssh_key_path="$(mktemp -d)/id_rsa";

    # Initialize some values
    init_wercker_environment_variables;
    init_netrc "$WERCKER_HEROKU_DEPLOY_USER" "$WERCKER_HEROKU_DEPLOY_KEY";
    init_ssh;
    init_git "$WERCKER_HEROKU_DEPLOY_USER" "$WERCKER_HEROKU_DEPLOY_USER";
    init_gitssh "$gitssh_path" "$ssh_key_path";

    cd "$WERCKER_HEROKU_DEPLOY_SOURCE_DIR" || fail "could not change directory to source_dir \"$WERCKER_HEROKU_DEPLOY_SOURCE_DIR\""

    # Only test authentication if:
    # - A run command was specified, or
    # - No custom ssh key was specified
    if [ -n "$WERCKER_HEROKU_DEPLOY_RUN" -o -z "$WERCKER_HEROKU_DEPLOY_KEY_NAME" ]; then
        # verify user and key not empty
        if [ -z "$WERCKER_HEROKU_DEPLOY_USER" ]; then
            fail "user property is required"
        fi

        if [ -z "$WERCKER_HEROKU_DEPLOY_KEY" ]; then
            fail "key property is required (API key)"
        fi

        test_authentication "$WERCKER_HEROKU_DEPLOY_APP_NAME";
    fi

    # Check if the user supplied a wercker key-name
    if [ -n "$WERCKER_HEROKU_DEPLOY_KEY_NAME" ]; then
        use_wercker_ssh_key "$ssh_key_path" "$WERCKER_HEROKU_DEPLOY_KEY_NAME";
    else
        use_random_ssh_key "$ssh_key_path";
    fi

    # Then check if the user wants to use the git repository or use the files in the source directory
    if [ "$WERCKER_HEROKU_DEPLOY_KEEP_REPOSITORY" == "true" ]; then
        use_current_git_directory "$WERCKER_HEROKU_DEPLOY_SOURCE_DIR" "$WERCKER_GIT_BRANCH";
    else
        use_new_git_repository "$WERCKER_HEROKU_DEPLOY_SOURCE_DIR";
    fi

    # Try to push the code
    set +e;
    push_code "$WERCKER_HEROKU_DEPLOY_APP_NAME";
    exit_code_push=$?
    set -e;

    # Retry pushing the code, if the first push failed and retry was not disabled
    if [ $exit_code_push -ne 0 ]; then
        if [ "$WERCKER_HEROKU_DEPLOY_RETRY" == "false" ]; then
            info "push failed, not going to retry";
        else
            info "push failed, retrying push in 5 seconds";
            sleep 5;

            set +e;
            push_code "$WERCKER_HEROKU_DEPLOY_APP_NAME";
            exit_code_push=$?
            set -e;
        fi
    fi

    if [ "$WERCKER_HEROKU_DEPLOY_INSTALL_TOOLBELT" == "true" -o -n "$WERCKER_HEROKU_DEPLOY_RUN" ]; then
        install_toolbelt;
    fi

    # Run a command, if the push succeeded and the user supplied a run command
    if [ -n "$WERCKER_HEROKU_DEPLOY_RUN" ]; then
        if [ $exit_code_push -eq 0 ]; then
            set +e;
            execute_heroku_command "$WERCKER_HEROKU_DEPLOY_APP_NAME" "$WERCKER_HEROKU_DEPLOY_RUN";
            exit_code_run=$?
            set -e;
        fi
    fi

    # Remove a auto generated key (assuming we generated a public key at ${ssh_key_path}.pub)
    if [ -z "$WERCKER_HEROKU_DEPLOY_KEY_NAME" ]; then
        remove_ssh_key "${ssh_key_path}.pub";
    fi

    if [ $exit_code_run -ne 0 ]; then
        fail 'heroku run failed';
    fi

    if [ $exit_code_push -eq 0 ]; then
        success 'deployment to heroku finished successfully';
    else
        fail 'git push to heroku failed';
    fi
}

init_wercker_environment_variables() {
    if [ -z "$WERCKER_HEROKU_DEPLOY_KEY" ]; then
        export WERCKER_HEROKU_DEPLOY_KEY="$HEROKU_KEY";
    fi

    if [ -z "$WERCKER_HEROKU_DEPLOY_APP_NAME" ]; then
        export WERCKER_HEROKU_DEPLOY_APP_NAME="$HEROKU_APP_NAME";
    fi

    if [ -z "$WERCKER_HEROKU_DEPLOY_APP_NAME" ]; then
        fail "app-name is required. User app-name parameter or \$HEROKU_APP_NAME environment variable"
    fi

    if [ -z "$WERCKER_HEROKU_DEPLOY_USER" ]; then
        if [ ! -z "$HEROKU_USER" ]; then
            export WERCKER_HEROKU_DEPLOY_USER="$HEROKU_USER";
        else
            export WERCKER_HEROKU_DEPLOY_USER="heroku-deploy@wercker.com";
        fi
    fi

    if [ -z "$WERCKER_HEROKU_DEPLOY_SOURCE_DIR" ]; then
        export WERCKER_HEROKU_DEPLOY_SOURCE_DIR="$WERCKER_ROOT";
        debug "option source_dir not set. Will deploy directory $WERCKER_HEROKU_DEPLOY_SOURCE_DIR";
    else
        warn "Use of source_dir is deprecated. Please make sure that you fix your Heroku deploy version on a major version."
        debug "option source_dir found. Will deploy directory $WERCKER_HEROKU_DEPLOY_SOURCE_DIR";
    fi
}

# init_netrc($username, $password) appends the machine credentials for Heroku to
# the ~/.netrc file, make sure it is .
init_netrc() {
    local username="$1";
    local password="$2";
    local netrc="$HOME/.netrc";

    {
        echo "machine api.heroku.com"
        echo "  login $username"
        echo "  password $password"
    } >> "$netrc"

    chmod 0600 "$netrc";
}

# init_ssh will add the public key of Heroku to the known_hosts file (after
# making sure it exists, and has proper permissions)
init_ssh() {
    local heroku_public_key="heroku.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAu8erSx6jh+8ztsfHwkNeFr/SZaSOcvoa8AyMpaerGIPZDB2TKNgNkMSYTLYGDK2ivsqXopo2W7dpQRBIVF80q9mNXy5tbt1WE04gbOBB26Wn2hF4bk3Tu+BNMFbvMjPbkVlC2hcFuQJdH4T2i/dtauyTpJbD/6ExHR9XYVhdhdMs0JsjP/Q5FNoWh2ff9YbZVpDQSTPvusUp4liLjPfa/i0t+2LpNCeWy8Y+V9gUlDWiyYwrfMVI0UwNCZZKHs1Unpc11/4HLitQRtvuk0Ot5qwwBxbmtvCDKZvj1aFBid71/mYdGRPYZMIxq1zgP1acePC1zfTG/lvuQ7d0Pe0kaw==";

    mkdir -p "$HOME/.ssh";
    touch "$HOME/.ssh/known_hosts";
    chmod 600 "$HOME/.ssh/known_hosts";
    echo "$heroku_public_key" >> "$HOME/.ssh/known_hosts";
}

# init_git checks that git exists, and that
init_git() {
    local username="$1";
    local email="$2";

    if ! type git &> /dev/null; then
        if ! type apt-get &> /dev/null; then
            fail "git is not available. Install it, and make sure it is available in \$PATH"
        else
            debug "git not found; installing it."

            sudo apt-get update;
            sudo apt-get install git-core -y;
        fi
    fi

    git config --global user.name "$username";
    git config --global user.email "$email";
}

init_gitssh() {
    local gitssh_path="$1";
    local ssh_key_path="$2";

    echo "ssh -e none -i \"$ssh_key_path\" \$@" > "$gitssh_path";
    chmod 0700 "$gitssh_path";
    export GIT_SSH="$gitssh_path";
}

install_toolbelt() {
    check_ruby;

    if ! type heroku &> /dev/null; then
        info 'heroku toolbelt not found, starting installing it';

        # extract from $steproot/heroku-client.tgz into /usr/local/heroku
        sudo rm -rf /usr/local/heroku
        sudo cp -r "$WERCKER_STEP_ROOT/vendor/heroku" /usr/local/heroku
        export PATH="/usr/local/heroku/bin:$PATH"

        info 'finished heroku toolbelt installation';
    else
        info 'heroku toolbelt is available, and will not be installed by this step';
    fi

    debug "type heroku: $(type heroku)";
    debug "heroku version: $(heroku --version)";
}

use_wercker_ssh_key() {
    local ssh_key_path="$1";
    local wercker_ssh_key_name="$2";

    debug "will use specified key in key-name option: ${wercker_ssh_key_name}_PRIVATE";

    local private_key;
    private_key=$(eval echo "\$${wercker_ssh_key_name}_PRIVATE");

    if [ ! -n "$private_key" ]; then
        fail 'Missing key error. The key-name is specified, but no key with this name could be found. Make sure you generated an key, and exported it as an environment variable.';
    fi

    debug "writing key file to $ssh_key_path";
    echo -e "$private_key" > "$ssh_key_path";
    chmod 0600 "$ssh_key_path";
}

use_random_ssh_key() {
    local ssh_key_path="$1";

    local ssh_key_comment="deploy-$RANDOM@wercker.com";

    debug "no key-name specified, will generate key and add it to heroku";

    debug 'generating random ssh key for this deploy';
    ssh-keygen -f "$ssh_key_path" -C "$ssh_key_comment" -N '' -t rsa -q -b 4096;
    debug "generated ssh key $ssh_key_comment for this deployment";
    chmod 0600 "$ssh_key_path";

    add_ssh_key "${ssh_key_path}.pub";
}

push_code() {
    local app_name="$1";

    debug "starting heroku deployment with git push";
    git push -f "git@heroku.com:$app_name.git" HEAD:master;
    local exit_code_push=$?;

    debug "git pushed exited with $exit_code_push";
    return $exit_code_push;
}

execute_heroku_command() {
    local app_name="$1";
    local command="$2";

    debug "starting heroku run $command";
    heroku run "$command" --app "$app_name";
    local exit_code_run=$?;

    debug "heroku run exited with $exit_code_run";
    return $exit_code_run;
}

add_ssh_key() {
    local public_key_path="$1";

    local public_key;
    public_key=$(cat "$public_key_path");

    debug "Adding ssh key to Heroku account"

    curl -n -X POST https://api.heroku.com/account/keys \
        -H "Accept: application/vnd.heroku+json; version=3" \
        -H "Content-Type: application/json" \
        -d "{\"public_key\":\"$public_key\"}" > /dev/null 2>&1;
}

calculate_fingerprint() {
    local public_key_path="$1";

    ssh-keygen -lf "$public_key_path" | awk '{print $2}';
}

remove_ssh_key() {
    local public_key_path="$1";

    local fingerprint;
    fingerprint=$(calculate_fingerprint "$public_key_path");

    debug "Removing ssh key from Heroku account (fingerprint: $fingerprint)"

     curl -n -X DELETE "https://api.heroku.com/account/keys/$fingerprint" \
        -H "Accept: application/vnd.heroku+json; version=3" > /dev/null 2>&1;
}

use_current_git_directory() {
    local working_directory="$1";
    local branch="$2";

    debug "keeping git repository"
    if [ -d "$working_directory/.git" ]; then
        debug "found git repository in $working_directory";
    else
        fail "no git repository found to push";
    fi

    git checkout "$branch"
}

use_new_git_repository() {
    local working_directory="$1"

    # If there is a git repository, remove it because
    # we want to create a new git repository to push
    # to heroku.
    if [ -d "$working_directory/.git" ]; then
        debug "found git repository in $working_directory"
        warn "Removing git repository from $working_directory"
        rm -rf "$working_directory/.git"

        #submodules found are flattened
        if [ -f "$working_directory/.gitmodules" ]; then
            debug "found possible git submodule(s) usage"
            while IFS= read -r -d '' file
            do
                rm -f "$file" && warn "Removed submodule $file"
            done < <(find "$working_directory" -type f -name ".git" -print0)
        fi
    fi

    # Create git repository and add all files.
    # This repository will get pushed to heroku.
    git init
    git add .
    git commit -m 'wercker deploy'
}

test_authentication() {
    local app_name="$1"

    check_curl;

    set +e;
    curl -n --fail \
        -H "Accept: application/vnd.heroku+json; version=3" \
        https://api.heroku.com/account > /dev/null 2>&1;
    local exit_code_authentication_test=$?;
    set -e;

    if [ $exit_code_authentication_test -ne 0 ]; then
        fail 'Unable to retrieve account information, please update your Heroku API key';
    fi

    set +e;
    curl -n --fail \
        -H "Accept: application/vnd.heroku+json; version=3" \
        "https://api.heroku.com/apps/$app_name" > /dev/null 2>&1;
    local exit_code_app_test=$?
    set -e;

    if [ $exit_code_app_test -ne 0 ]; then
        fail 'Unable to retrieve application information, please check if the Heroku application still exists';
    fi
}

check_curl() {
    if ! type curl &> /dev/null; then
        if ! type apt-get &> /dev/null; then
            fail "curl is not available. Install it, and make sure it is available in \$PATH"
        else
            debug "curl not found; installing it."

            sudo apt-get update;
            sudo apt-get install curl -y;
        fi
    fi
}

check_ruby() {
    if ! type ruby &> /dev/null; then
        if ! type apt-get &> /dev/null; then
            fail "ruby is not available. Install it, and make sure it is available in \$PATH"
        else
            debug "ruby not found; installing it."

            sudo apt-get update;
            sudo apt-get install ruby-full -y;
        fi
    fi
}

main;
