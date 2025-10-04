call set_volume_paths.bat
docker run -i -t^
  -v %data_dir%:/data^
  -v %dolt_dir%:/root/.dolt^
  optionsmile:latest
