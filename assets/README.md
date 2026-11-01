# Logo artwork

`rubocop-logo.svg` is an unchanged copy of [the official website's SVG](https://github.com/rubocop/rubocop.org/blob/e48d295d87264ea7dbfa0c6df7c7c4b56670979d/src/images/favicon.svg). The [upstream conversion](https://github.com/rubocop/rubocop.org/commit/e48d295d87264ea7dbfa0c6df7c7c4b56670979d) uses paths from RuboCop's original MIT-licensed vector artwork. Its copyright and permission notice is preserved in [RUBOCOP-LICENSE](RUBOCOP-LICENSE).

`logo.svg` places that SVG alongside a pencil drawn for rubocop-spellcheck. A white background keeps the original black artwork visible on dark pages. Keep `rubocop-logo.svg` beside the composition when editing or rendering it.

`logo.png` is the rendered README image. Regenerate it with:

```sh
rsvg-convert assets/logo.svg -o assets/logo.png
```
