# chrootctl

**A command-line tool to manage chroot environments on Alpine Linux.**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## Table of Contents

- [About](#about)
- [Features](#features)
- [Installation](#installation)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

---

## About

**To keep my main system clean I often use chroot environments to run different versions of Linux or test software.**

- What the project does: It provide a command-line tool to easily manage chroot environments on Alpine Linux.
- Why it exists: Mainly to help me achieve my goal of keeping my main system clean but you might be interested in using it for other purposes.
- Who it’s for: Anyone who wants to manage chroot environments on Alpine Linux.

---

## Features

- Create: create a chroot environment.
- Enter: enter a chroot environment.
- Save: save a chroot environment.
- Delete: delete a chroot environment.
- List: list all chroot environments.
- Cache: list all cached distributions.
- Saved: list all saved chroot environments.

---

## Installation

### Prerequisites

- No dependencies, yay!
- POSIX-compliant shell
- An Alpine Linux system of course ;)

### Steps

1. Clone the repository:

   ```sh
   git clone https://github.com/armrib/alpine-chrootctl.git
   ```

2. Run the install script:

```sh
cd alpine-chrootctl
./install.sh
```

3. Enjoy!

```sh
chrootctl help
```

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test thoroughly
4. Submit a pull request

## License

This project is licensed under the MIT License - see LICENSE file for details.

## Acknowledgments

- [Alpine wiki](https://wiki.alpinelinux.org/wiki/Alpine_Linux_in_a_chroot)
- [Alpine chroot install](https://github.com/alpinelinux/alpine-chroot-install/)
- Many more I landed on the internet...

