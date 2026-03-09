#!/bin/sh
cat <<EOF > /data/_quarto.yml
project:
  output-dir: output
execute:
  cache: true

format:
  html: default
  pdf: default
EOF

printf "Watching for .qmd file changes in /data"

mkdir -p /tmp/build/

# watch recursively (-r), only .qmd files (-e), run command on change (-c)
watchexec --emit-events-to=environment -r -e qmd ' \
	file=$WATCHEXEC_WRITTEN_PATH \
	filename=${file%.qmd} \

	echo "Rendering $WATCHEXEC_COMMON_PATH/$WATCHEXEC_WRITTEN_PATH"; \
	cp /$WATCHEXEC_COMMON_PATH/$WATCHEXEC_WRITTEN_PATH /tmp/build/$WATCHEXEC_WRITTEN_PATH; \
	cp _quarto.yml /tmp/build/_quarto.yml; \
	quarto render /tmp/build/$WATCHEXEC_WRITTEN_PATH --to html; \
	echo "MAKING $WATCHEXEC_COMMON_PATH/output"; \
	cp /tmp/build/output/*.html $WATCHEXEC_COMMON_PATH/output/; \
	cp -r /tmp/build/output/"${filename}_files" $WATCHEXEC_COMMON_PATH/output/"${filename}_files"; \
	cp /tmp/build/output/*.pdf $WATCHEXEC_COMMON_PATH/output/; \
	rm -rf /tmp/build/outpout; \
'
