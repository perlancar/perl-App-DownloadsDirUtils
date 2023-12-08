package App::DownloadsDirUtils;

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Exporter 'import';
use File::Util::Sort;
use Perinci::Object;
use Perinci::Sub::Util qw(gen_modified_sub);

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

$SPEC{list_downloads_dirs} = {
    v => 1.1,
    summary => 'List downloads directories',
    result_naked => 1,
};
sub list_downloads_dirs {
    require File::HomeDir;

    my @res;
    my $home;

    # ~/Downloads - firefox, ...
    {
        $home //= File::HomeDir->my_home;
        push @res, "$home/Downloads";
    }

    # mldonkey
    {
        $home //= File::HomeDir->my_home;
        push @res, "$home/.mldonkey/incoming/files";
    }

    @res = grep {-d} @res;

    wantarray ? @res : \@res;
}

for my $which (qw/foremost hindmost largest smallest newest oldest/) {
    my $res;

    $res = gen_modified_sub(
        summary => "Return the $which file(s) in the downloads directories",
        description => <<"MARKDOWN",

This is a thin wrapper for the <prog:$which> utility; the wrapper sets the
default for the directories to the downloads directories, as well as by default
excluding partial downloads (`*.part` files).

MARKDOWN
        output_name => __PACKAGE__ . "::${which}_download",
        base_name   => "File::Util::Sort::$which",
        modify_args => {
            dirs => sub {
                my $arg_spec = shift;
                $arg_spec->{default} = scalar list_downloads_dirs();
            },
            exclude_filename_pattern => sub {
                my $arg_spec = shift;
                $arg_spec->{default} = '/\.part\z/';
            },
        },
        output_code => sub {
            no strict 'refs'; ## no critic: TestingAndDebugging::ProhibitNoStrict
            my %args = @_;
            $args{dirs} //= scalar list_downloads_dirs();
            $args{exclude_filename_pattern} //= qr/\.part\z/;
            &{"File::Util::Sort::$which"}(%args);
        },
    );
    die "Can't generate ${which}_download(): $res->[0] - $res->[1]"
        unless $res->[0] == 200;

    $res = gen_modified_sub(
        summary => "Move the $which file(s) from the downloads directories to current directory",
        description => <<"MARKDOWN",

This is a thin wrapper for the <prog:${which}-download> utility; the wrapper
moves the files to current directory. It hopes to be a convenient helper to
organize your downloads.

MARKDOWN
        output_name => "mv_${which}_download_here",
        base_name   => "${which}_download",
        add_args => {
            to_dir => {
                schema => 'dirname*',
                default => '.',
            },
            overwrite => {
                schema => 'true*',
                cmdline_aliases => {O=>{}},
            },
            as => {
                summary => 'Rename file',
                schema => 'pathname::unix::basename*',
            },
        },
        modify_meta => sub {
            my $meta = shift;
            $meta->{features} //= {};
            $meta->{features}{dry_run} = 1;
        },
        output_code => sub {
            no strict 'refs'; ## no critic: TestingAndDebugging::ProhibitNoStrict
            require File::Copy::Recursive;

            my %args = @_;

            my $to_dir = delete($args{to_dir}) // '.';

            my $res = &{"${which}_download"}(%args);
            return $res unless $res->[0] == 200;
            return [404, "No $which file(s) returned"] unless @{ $res->[2] };

            my $envres = envresmulti();
            my $i = 0;
            for my $file (@{ $res->[2] }) {
                $i++;
                my $targetpath = $to_dir . '/' . ($args{as} // $file);
                if (-e $targetpath && !$args{overwrite}) {
                    $envres->add_result(409, "File already exist '$targetpath', please specify -O to overwrite", {item_id=>$file});
                } elsif ($args{-dry_run}) {
                    log_info "DRY-RUN: [%d/%d] Moving %s to %s ...", $i, scalar(@{ $res->[2] }), $file, $to_dir;
                    $envres->add_result(200, "OK (dry-run)", {item_id=>$file});
                } else {
                    log_info "[%d/%d] Moving %s to %s ...", $i, scalar(@{ $res->[2] }), $file, $to_dir;
                    my $ok = File::Copy::Recursive::rmove($file, $to_dir);
                    if ($ok) {
                        $envres->add_result(200, "OK", {item_id=>$file});
                    } else {
                        $envres->add_result(500, "Error: $!", {item_id=>$file});
                    }
                }
            }
            $envres->as_struct;
        },
    );
    die "Can't generate mv_${which}_download_here(): $res->[0] - $res->[1]"
        unless $res->[0] == 200;
} # $which

1;
#ABSTRACT: Utilities related to downloads directories

=head1 DESCRIPTION

This distribution provides the following command-line utilities:

# INSERT_EXECS_LIST


=head1 SEE ALSO

=cut
