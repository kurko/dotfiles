function extract_all_zips() {
  ruby -e 'require "shellwords"; Dir.glob("./**/*.zip").each { |f| `unzip #{Shellwords.escape(f)} -d #{Shellwords.escape(File.dirname(f))}` }'
}
