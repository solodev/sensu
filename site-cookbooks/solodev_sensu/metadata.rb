name 'solodev_sensu'
maintainer 'Solodev'
maintainer_email 'smoore@solodev.com'
license 'all_rights'
description 'Installs/Configures solodev_sensu'
long_description 'Installs/Configures solodev_sensu'
version '0.1.0'

depends "sensu"
depends "hostsfile"
depends "citadel"
depends "influxdb"

# If you upload to Supermarket you should set this so your cookbook
# gets a `View Issues` link
# issues_url 'https://github.com/<insert_org_here>/solodev_sensu/issues' if respond_to?(:issues_url)

# If you upload to Supermarket you should set this so your cookbook
# gets a `View Source` link
# source_url 'https://github.com/<insert_org_here>/solodev_sensu' if respond_to?(:source_url)
