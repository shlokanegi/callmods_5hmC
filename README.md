# Callmods 5hmC workflow
This workflow generates high-confidence 5hmC mod calls from an aligned modbam using modkit, and other stats and plots.

## Test locally
```sh
## Run with miniwdl
miniwdl run --as-me -i inputs.json workflow.wdl
## Run with cromwell
java -jar cromwell run workflow.wdl -i inputs.json
```

## Test with Toil
```sh
toil-wdl-runner workflow.wdl --inputs inputs.json
```