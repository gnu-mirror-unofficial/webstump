#!/usr/bin/env perl
#
# Copyright 1999 Igor Chudov
#
# This file is part of WebSTUMP.
# 
# WebSTUMP is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# WebSTUMP is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with WebSTUMP.  If not, see <https://www.gnu.org/licenses/>.
#
# This script creates a new newsgroup.
#

if( !($0 =~ /\/scripts\/create-newsgroup\.pl$/) ) {
  die "This script can only be called with full path name!!!";
}

$webstump_home = $0;
$webstump_home =~ s/\/scripts\/create-newsgroup\.pl$//;

require "$webstump_home/config/webstump.cfg";
require "$webstump_home/scripts/webstump.lib.pl";

&init_webstump;

$newsgroup = @ARGV[0];
$address = @ARGV[1];
$password = @ARGV[2];

print "Creating newsgroup:
Name: $newsgroup
Approval Address: $address
Admin password: $password
Press ENTER to continue, ^C to interrupt:\n";

<STDIN>;

print "Adding $newsgroup to $webstump_home/config/newsgroups.lst...";
&append_to_file( "$webstump_home/config/newsgroups.lst", 
                "$newsgroup  $address\n" );
mkdir "$webstump_home/queues/$newsgroup", 0755;
print " done.\n";

$dir = "$webstump_home/config/newsgroups/$newsgroup";

print "Creating $dir...";
mkdir $dir, 0755;
print " done.\n";

print "Creating files in $dir...";

&append_to_file( "$dir/blacklist", "" );
&append_to_file( "$dir/moderators", "ADMIN \U$password\n" );
&append_to_file( "$dir/rejection-reasons", 
"offtopic::a blatantly offtopic article
harassing::message of harassing content
charter::message poorly formatted
ignore::Discard message without notifying sender (spam etc)
" );
&append_to_file( "$dir/whitelist", "" );
print " done.\n";
