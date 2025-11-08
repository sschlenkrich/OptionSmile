call set_volume_paths.bat
docker run -it --rm^
  -v %data_dir%:/data^
  -v %dolt_dir%:/root/.dolt^
  -p 8001:8000^
  sschlenkrich/optionsmile_genie:latest^
  %1
