# resize_large_images - Resize images in a directory using ImageMagick
#
# Resizes all images in the specified directory to a maximum width while preserving
# aspect ratio. This operation modifies files IN PLACE with no backup.
#
# Usage:
#   resize_large_images <directory> [OPTIONS]
#
# Arguments:
#   <directory>     Path to directory containing images to resize
#
# Options:
#   --max_width N   Maximum width in pixels (default: 3600)
#   --yes           Skip confirmation prompt
#   --dry-run       Show what would be resized without actually doing it
#   --verbose       Show detailed ImageMagick progress
#
# Examples:
#   resize_large_images ~/Photos/vacation
#   resize_large_images ~/Photos --max_width 2400 --yes
#   resize_large_images ~/Photos --dry-run
#
# Supported formats: JPG, JPEG, PNG, WEBP, GIF, TIFF
#
function resize_large_images {
  local directory=""
  local max_width="3600"
  local yes_flag=false
  local dry_run=false
  local verbose_flag=false

  # Check for ImageMagick installation
  if ! command -v magick &> /dev/null; then
    echo "Error: ImageMagick is not installed"
    echo "Install with: brew install imagemagick"
    return 1
  fi

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --max_width)
        if [[ -z "$2" ]] || [[ "$2" =~ ^-- ]]; then
          echo "Error: --max_width requires a numeric argument"
          return 1
        fi
        max_width="$2"
        shift 2
        ;;
      --yes)
        yes_flag=true
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --verbose)
        verbose_flag=true
        shift
        ;;
      *)
        if [[ -z "$directory" ]]; then
          directory="$1"
        else
          echo "Error: Unexpected argument '$1'"
          echo "Usage: resize_large_images <directory> [OPTIONS]"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate directory argument
  if [[ -z "$directory" ]]; then
    echo "Usage: resize_large_images <directory> [OPTIONS]"
    return 1
  fi

  if [[ ! -d "$directory" ]]; then
    echo "Error: '$directory' is not a directory"
    return 1
  fi

  # Build file pattern - if directory doesn't already have extension pattern, add it
  local subject_directory="$directory"
  if [[ "$subject_directory" == */ ]] || [[ ! "$subject_directory" =~ \*\. ]]; then
    subject_directory="${subject_directory%/}/*.{jpeg,JPEG,jpg,JPG,png,PNG,webp,WEBP,gif,GIF,tiff,TIFF}"
  fi

  # Count matching files
  local file_count=0
  for ext in jpg jpeg png webp gif tiff JPG JPEG PNG WEBP GIF TIFF; do
    file_count=$((file_count + $(find "$directory" -maxdepth 1 -type f -iname "*.$ext" 2>/dev/null | wc -l)))
  done

  if [[ $file_count -eq 0 ]]; then
    echo "No matching image files found in $directory"
    return 1
  fi

  # Display operation details
  echo "Found $file_count image(s) to resize"
  echo "Directory: $directory"
  echo "Max width: ${max_width}px"

  if [[ "$dry_run" == true ]]; then
    echo ""
    echo "[DRY RUN] Would resize the following files:"
    for ext in jpg jpeg png webp gif tiff JPG JPEG PNG WEBP GIF TIFF; do
      find "$directory" -maxdepth 1 -type f -iname "*.$ext" 2>/dev/null
    done
    return 0
  fi

  # Confirm with user unless --yes flag is set
  if [[ "$yes_flag" == false ]]; then
    echo ""
    echo "WARNING: This will PERMANENTLY modify images in place (no backup)"
    echo "Images will be resized to max width of ${max_width}px and EXIF data will be stripped"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Aborting"
      return 1
    fi
  fi

  # Build ImageMagick command
  local mogrify_opts="-strip -resize ${max_width}>"
  if [[ "$verbose_flag" == true ]]; then
    mogrify_opts="-verbose $mogrify_opts"
  fi

  # Execute resize operation
  echo "Resizing images..."
  magick mogrify $mogrify_opts "$subject_directory"

  echo "✓ Resize complete! Processed $file_count image(s)"
}

# Modelines
# vim: set filetype=sh :
