package App::DownloadsDirUtils;

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Exporter 'import';
use App::FileSortUtils;
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
    my $res = gen_modified_sub(
        summary => "Return the $which file(s) in the downloads directories",
        description => <<"MARKDOWN",

This is a thin wrapper for the <prog:$which> utility; the wrapper sets the
default for the directories to the downloads directories, as well as by default
excluding partial downloads (`*.part` files).

MARKDOWN
        output_name => __PACKAGE__ . "::${which}_download",
        base_name   => "App::FileSortUtils::$which",
        modify_args => {
            dirs => sub {
                my $arg_spec = shift;
                $arg_spec->{default} = scalar list_downloads_dirs();
            },
            exclude_filename_pattern => sub {
                my $arg_spec = shift;
                $arg_spec->{default} = qr/\.part\z/;
            },
        },
        output_code => sub {
            no strict 'refs'; ## no critic: TestingAndDebugging::ProhibitNoStrict
            my %args = @_;
            $args{dirs} //= scalar list_downloads_dirs();
            &{"App::FileSortUtils::$which"}(%args);
        },
    );
    die "Can't generate ${which}_download(): $res->[0] - $res->[1]"
        unless $res->[0] == 200;
} # $which

1;
#ABSTRACT: Utilities related to downloads directories

=head1 DESCRIPTION

This distribution provides the following command-line utilities:

# INSERT_EXECS_LIST


=head1 SEE ALSO

=cut
