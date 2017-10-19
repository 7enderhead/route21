SERVER=192.168.0.26 &&
USER=root &&
PASSWORD=MySql123 && 
DB=map &&
TABLE=stop && # MySql access data
OSM_ARCHIVE=austria-latest.osm.bz2 && # bz2-compressed input osm file
mysql -h $SERVER -u $USER -p$PASSWORD -e " \
CREATE DATABASE IF NOT EXISTS $DB \
  DEFAULT CHARACTER SET utf8 \
  DEFAULT COLLATE utf8_general_ci; \
USE $DB; \
DROP TABLE IF EXISTS $TABLE; \
CREATE TABLE $TABLE ( \
  id BIGINT NOT NULL PRIMARY KEY, \
  lon DECIMAL(11,8), \
  lat DECIMAL(11,8), \
  name VARCHAR(100), \
  alt_name VARCHAR(100) \
);" && # setup database (if necessary) and table
FIFO_BASE=`mktemp` && FIFO=$FIFO_BASE.fifo && # setup named pipe used for MySql LOAD DATA input instead of file
mkfifo $FIFO && ( \
TMP=`mktemp` && # temp file used later for osmfilter, which needs a random access file input
bzip2 -d -c $OSM_ARCHIVE | # unzip directly to a stream
osmconvert - -B=Graz.poly > $TMP && # it is _much_ faster (and needs much less disk space) to first cut out the region...
osmfilter $TMP --keep="railway=tram_stop or highway=bus_stop" | # ... and only then filter for stops
osmconvert - --all-to-nodes --csv="@id @lon @lat name alt_name" | # CSV conversion
awk -F"\t" '$4 != ""' > $FIFO & # name (field 4) must not be empty; redirect results into named pipe and wait in background for data consumption
mysql -h $SERVER -u $USER -p$PASSWORD --local-infile -e " \
LOAD DATA LOCAL INFILE '$FIFO' INTO TABLE $DB.$TABLE \
  FIELDS TERMINATED BY '\t' \
  LINES TERMINATED BY '\n';" \
) && # load data from named pipe into table
\rm -f $FIFO_BASE ; \rm -f $FIFO ; \rm -f $TMP # clean up temp files
