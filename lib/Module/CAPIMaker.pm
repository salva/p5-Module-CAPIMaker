package Module::CAPIMaker;

our $VERSION = '0.01';

use strict;
use warnings;

use Text::Template;
use File::Spec;
use POSIX qw(strftime);


use Module::CAPIMaker::Template::Module_H;
use Module::CAPIMaker::Template::Module_C;
use Module::CAPIMaker::Template::Sample_XS;
use Module::CAPIMaker::Template::C_API_H;

sub new {
    my $class = shift;
    my %config = @_;
    my $self = { config => \%config,
                 function => {},
                 data => {}
               };

    $config{decl_filename} //= 'c_api.decl';

    bless $self, $class;
}

sub load_decl {
    my $self = shift;
    my $config = $self->{config};
    my $fn = $config->{decl_filename};
    open my $fh, '<', $fn or die "Unable to open $fn: $!\n";
    while (<$fh>) {
        chomp;
        s/^\s+//; s/\s+$//;
        next if /^(?:#.*)?$/;
        while (s/\s*\\$/ /) {
            my $next = <$fh>;
            chomp $next;
            $next =~ s/^\s+//; $next =~ s/\s+$//;
            $_ .= $next;
        }
        if (my ($k, $v) = /^(\w+)\s*=\s*(.*)/) {
            if (my ($mark) = $v =~ /^<<\s*(\w+)$/) {
                $v = '';
                while (1) {
                    my $line = <$fh>;
                    defined $line or die "Ending token '$mark' missing at $fn line $.\n";
                    last if $line =~ /^$mark$/;
                    $v .= $line;
                }
            }
            $self->{config}{$k} = $v;
        }
        elsif (/^((?:\w+\b\s*(?:\*+\s*)?)*)(\w+)\s*\(\s*(.*?)\s*\)$/) {
            my $args = $3;
            my %f = ( decl => $_,
                      type => $1,
                      name => $2,
                      args => $args );
            $self->{function}{$2} = \%f;

            if ($f{pTHX} = $args =~ s/^pTHX(?:_\s+|$)//) {
                $args =~ s/^void$//;
                my @args = split /\s*,\s*/, $args;
                # warn "args |$args| => |". join('-', @args) . "|";
                $f{macro_args} = join(', ', ('a'..'z')[0..$#args]);
                $f{call_args} = (@args ? 'aTHX_ (' . join('), (', ('a'..'z')[0..$#args]) .')' : 'aTHX');
            }

        }
        else {
            die "Invalid declaration at $fn line $.\n";
        }
    }
}

sub check_config {
    my $self = shift;
    my $config = $self->{config};

    my $module_name = $config->{module_name};
    die "module_name declaration missing from $config->{decl_filename}\n"
        unless defined $module_name;

    die "Invalid value for module_name ($module_name)\n"
        unless $module_name =~ /^\w+(?:::\w+)*$/;

    my $c_module_name = $config->{c_module_name} //= do { my $cmn = lc $module_name;
                                                          $cmn =~ s/\W+/_/g;
                                                          $cmn };
    die "Invalid value for c_module_name ($c_module_name)\n"
        unless $c_module_name =~ /^\w+$/;

    $config->{author} //= 'Unknown';
    $config->{min_version} //= 1;
    $config->{max_version} //= 1;

    die "Invalid version declaration, min_version ($config->{min_version}) > max_version ($config->{max_version})\n"
        if $config->{max_version} < $config->{min_version};

    $config->{required_version} //= $config->{max_version};
    $config->{module_version} //= '0';
    $config->{capimaker_version} = $VERSION;

    $config->{now} = strftime("%F %T", localtime);

    $config->{destination_dir} //= 'c_api';

    $config->{module_c_filename}  //= "perl_$c_module_name.c";
    $config->{module_h_filename}  //= "perl_$c_module_name.h";
    $config->{sample_xs_filename} //= "sample.xs";
    $config->{c_api_h_filename}   //= "c_api.h";

    $config->{module_h_barrier} //= do { my $ib = "$config->{module_h_filename}_INCLUDED";
                                         $ib =~ s/\W+/_/g;
                                         uc $ib };
    die "Invalid value for module_h_barrier ($config->{module_h_barrier})\n"
        unless $config->{module_h_barrier} =~ /^\w+$/;

    $config->{c_api_h_barrier}  //= do { my $ib = "$config->{c_api_h_filename}_INCLUDED";
                                         $ib =~ s/\W+/_/g;
                                         uc $ib };
    die "Invalid value for c_api_h_barrier ($config->{c_api_h_barrier})\n"
        unless $config->{c_api_h_barrier} =~ /^\w+$/;


    $config->{$_} //= '' for qw(export_prefix
                                module_c_beginning
                                module_c_end
                                module_h_beginning
                                module_h_end);
}

sub gen_file {
    my ($self, $template, $dir, $save_as) = @_;
    my $config = $self->{config};
    system mkdir => -p => $dir unless -d $dir; # FIX ME!
    $save_as = File::Spec->rel2abs(File::Spec->join($dir, $save_as));
    open my $fh, '>', $save_as or die "Unable to create $save_as: $!\n";
    local $Text::Template::ERROR;
    my $tt = Text::Template->new(TYPE => (ref $template ? 'ARRAY' : 'FILE'),
                                 SOURCE => $template,
                                 DELIMITERS => ['<%', '%>'] );
    $tt->fill_in(HASH => { %$config, function => $self->{function} },
                 OUTPUT => $fh);
    warn "Some error happened while generating $save_as: $Text::Template::ERROR\n"
        if $Text::Template::ERROR;
}

sub gen_all {
    my $self = shift;
    my $config = $self->{config};
    $self->gen_file($config->{module_c_template_filename} // \@Module::CAPIMaker::Template::Module_C::template,
                    $config->{destination_dir},
                    $config->{module_c_filename});
    $self->gen_file($config->{module_h_template_filename} // \@Module::CAPIMaker::Template::Module_H::template,
                    $config->{destination_dir},
                    $config->{module_h_filename});
    $self->gen_file($config->{sample_xs_template_filename} // \@Module::CAPIMaker::Template::Sample_XS::template,
                    $config->{destination_dir},
                    $config->{sample_xs_filename});
    $self->gen_file($config->{c_api_h_template_filename} // \@Module::CAPIMaker::Template::C_API_H::template,
                    '.',
                    $config->{c_api_h_filename});
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Module::CAPIMaker - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Module::CAPIMaker;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Module::CAPIMaker, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Salvador Fandiño, E<lt>salva@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Salvador Fandiño

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
