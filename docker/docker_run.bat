call set_volume_paths.bat
docker run -it --rm^
  -v %data_dir%:/data^
  -v %dolt_dir%:/root/.dolt^
  optionsmile:alpine^
  %1
