if status is-interactive
# Commands to run in interactive sessions can go here
end

#set configs here
set -x SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
