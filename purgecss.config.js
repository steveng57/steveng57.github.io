module.exports = {
    content: ["./_site/**/*.html"],
    css: ["./_site/assets/css/*.css"],
    defaultExtractor: content => content.match(/[\w-/:]+(?<!:)/g) || [],
    output: "./_site/assets/css/"
  }