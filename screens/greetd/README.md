# greetd greeter — real-seat captures

Framebuffer captures (QEMU QMP `screendump`, 1280×800) from the
clean-Arch VM graphical validation on 2026-11-25: the packaged
`hornero-greeter-greetd` running under cage as greetd's greeter on
seat0/tty1, driven with synthesized pointer/keyboard input.

| File | State |
|---|---|
| `01-sign-in.png` | Channel list, session selector, power rail |
| `02-password-prompt.png` | Live PAM `Password:` prompt (secret) |
| `03-login-failed.png` | After a wrong password: counted, honest retry copy |

The full journey (wrong → retry → correct password → Hyprland
desktop → logout back to this greeter) is recorded in
HorneroOS/qa#98. These are captures of the running greeter, not
renders: the clock, cursor and test account are the VM's.
