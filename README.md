# Developer Portal

[![Hugo](https://img.shields.io/static/v1?label=Hugo&message=0.161.1&color=blue&logo=hugo)](https://github.com/gohugoio/hugo/releases/tag/v0.161.1)
[![Theme Blowfish](https://img.shields.io/badge/Hugo--Themes-@Blowfish-blue)](https://themes.gohugo.io/themes/blowfish/)
[![Blowfish](https://img.shields.io/static/v1?label=Blowfish&message=2.103.0&color=blue)](https://github.com/nunocoracao/blowfish/releases/tag/v2.103.0)

[![Minimum Hugo Version](https://img.shields.io/static/v1?label=min-Hugo-version&message=0.158.0&color=blue&logo=hugo)](https://github.com/gohugoio/hugo/releases/tag/v0.158.0)
[![Maximum Hugo Version](https://img.shields.io/static/v1?label=max-Hugo-version&message=0.161.1&color=blue&logo=hugo)](https://github.com/gohugoio/hugo/releases/tag/v0.161.1)


This project stores the files for the [Espressif Developer Portal][] website. GitHub Actions statically generate the website using Hugo and pushes it to a web server for online hosting.

[Espressif Developer Portal]: https://developer.espressif.com/

This doesn't works. See [this](./content/blog/2025/03/esp32-bluetooth-clearing-the-air/index.md#impat)

Here is a list:

- Item 1
- Item 2

## Test Vale

### Headings Should Use Sentence Case

espressif designs WiFi and bluetooth SOCs.

Our ULP coprocessor uses an IMAC CPU.


## The Importance of the ESP-TEE

If you want to contribute to this project, it would be nice to see the rendered version. The website can be easily rendered on your local machine using the following steps:

1. Clone this repository using `git clone --recursive --shallow-submodules`.
2. Install Hugo following the [instructions](https://gohugo.io/installation/).
3. In the project folder, run `hugo server` and open the provided local web address, usually `http://localhost:1313/`.

See also the [Contribution Guide](https://developer.espressif.com/pages/contribution-guide/).
