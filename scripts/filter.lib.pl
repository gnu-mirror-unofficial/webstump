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
# This library of functions is used for filtering messages.
#
use strict;
use warnings;

use Webstump::ListAdmin qw(decisionForSTUMP);

# processes approval decision.
#
# Arguments: 
#
# Subject, newsgroup, ShortDirectoryName, decision, comment

sub process_approval_decision {

  my $comment = pop( @_ );
  my $decision = pop( @_ );
  my $ShortDirectoryName = pop( @_ );
  my $newsgroup = pop( @_ );
  my $Subject = pop( @_ );
  our %newsgroups_index;

  my $address = $newsgroups_index{$newsgroup};

  my $message = "To: $newsgroups_index{$newsgroup}\n" .
		"Subject: $Subject\n" .
                "Organization: http://www.algebra.com/~ichudov/stump\n";

  $message .= decisionForSTUMP($decision, $comment);
  &email_message( $message, $address );

print STDERR "DECISION: $decision for $ShortDirectoryName sent to $address, for $newsgroup\n";

  &rmdir_rf( article_file_name( $newsgroup, $ShortDirectoryName ) );

}


###################################################################### checkAck
# checks the string matches one of the substrings. A name is matched
# against the substrings as regexps and substrings as literal substrings.
#
# Arguments: address, listname
sub name_is_in_list { # address, listname
  my $listName = pop( @_ );
  my $address = pop( @_ );

  my $item = "";
  my $Result = "";

  $address = "\L$address";

  open( LIST, &full_config_file_name( $listName ) ) || return "";

  while( $item = <LIST> ) {

    chop $item;

    next if $item =~ /^\s*$/;

    my $quoted_item = quotemeta( $item );

    if( eval { $address =~ /$item/i; } || $address =~ /$quoted_item/i ) {
      $Result = $item;
    }
  }

  close( LIST );

  return $Result;
}

######################################################################
#
# If STUMP reported a bad Newsgroups header get what kind
# Use the Article_Head global for now as that is easier than picking
# headers out of the whole message.
#
######################################################################
sub get_bad_newsgroups_warning {
  my ($Article_Head) = @_;
  my ($kind) = $Article_Head =~ m{^X-STUMP-Warning: Newsgroups header (\w+)$}m;
  return $kind || q{};
}

######################################################################
# reviews incoming message and decides: approve, reject, keep
# in queue for human review
#
# Arguments: Newsgroup, From, Subject, Message, Dir
#
# RealSubject is the shorter subject from original posting
sub review_incoming_message {
  my ($article, $dir) = @_;
  my $message = $article->{Article_Head} . $article->{Article_Body};
  my $real_subject = $article->{Article_Subject};
  my $subject = $article->{Subject};
  my $from = $article->{Article_From};
  my $newsgroup = $article->{newsgroup};

  my $warning_file = &article_file_name($newsgroup, $dir) . "/stump-warning.txt";

  # Deal with bad Newsgroups header
  if( my $bad_header_kind = get_bad_newsgroups_warning($article->{Article_Head})) {
    my ($actions, $default) = get_bad_newsgroups_header_options($newsgroup);
    my $action = $actions->{$bad_header_kind};
    print LOG "Bad Newsgroups: header - $bad_header_kind - $action\n";
    if ($action eq 'warn') {
      &append_to_file( $warning_file, "Warning: Newsgroups header $bad_header_kind\n" );
    } elsif ($action =~ m/^reject/) {
      &process_approval_decision( $subject, $newsgroup, $dir, $action, "auto Newsgroups header $bad_header_kind" );
      return;
    }
    # noAction should be the only other possibility but unknown cases will be treeeateeed the same way.
  }
  if( &name_is_in_list( $from, "bad.posters.list" ) ) {
    &process_approval_decision( $subject, $newsgroup, $dir, "reject abuse", "" );
    return;
  }

  if( &name_is_in_list( $real_subject, "bad.subjects.list" ) ) {
    &process_approval_decision( $subject, $newsgroup, $dir, "reject thread", "" );
    return;
  }

  if( &name_is_in_list( $message, "bad.words.list" ) ) {
    &process_approval_decision( $subject, $newsgroup, $dir, "reject charter", 
    "Your message has been autorejected because it appears to be off topic
    based on our filtering criteria. Like everything, filters do not
    always work perfectly and you can always appeal this decision." );
    return;
  }

  my $match;

  our $ignore_demo_mode = 1;

  if( $match = &name_is_in_list( $from, "watch.posters.list" ) ) {
    &append_to_file( $warning_file, "Warning: poster '$from' matches '$match' from the list of suspicious posters\n" );
print STDERR "Filing Article for review because poster '$from' matches '$match'\n";
    return; # file message
  }

  if( $match = &name_is_in_list( $real_subject, "watch.subjects.list" ) ) {
    &append_to_file( $warning_file, "Warning: subject '$real_subject' matches '$match' from the list of suspicious subjects\n" );
print STDERR "Filing Article for review because subject '$subject' matches '$match'\n";
    return; # file message
  }

  if( $match = &name_is_in_list( $message, "watch.words.list" ) ) {
    &append_to_file( $warning_file, "Warning: article matches '$match' from the list of suspicious words\n" );
print STDERR "Filing Article for review because article matches '$match'\n";
    return; # file message
  }

  if( &name_is_in_list( $from, "good.posters.list" ) ) {
    &process_approval_decision( $subject, $newsgroup, $dir, "approve", "" );
    return;
  }

  if( &name_is_in_list( $real_subject, "good.subjects.list" ) ) {
    &process_approval_decision( $subject, $newsgroup, $dir, "approve", "" );
    return;
  }

  # if the message remains here, it is stored for human review.

}

1;
