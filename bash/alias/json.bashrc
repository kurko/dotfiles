# Given a file with JSON content, this will read the file, format it so the JSON
# shows up nicely (multiline etc) and then save into the file again.
#
# == Usage
#
# format_json_file <filepath>
function format_json_file() {
  FILE_PATH_TO_FORMAT=$1
  echo "$(cat $FILE_PATH_TO_FORMAT | jq . )" > $FILE_PATH_TO_FORMAT
}
alias json_formatted_file="format_json_file"
