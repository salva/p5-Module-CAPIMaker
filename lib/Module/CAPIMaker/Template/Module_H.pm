package Module::CAPIMaker::Template::Module_H;

local $.;
our @template = <DATA>;
close DATA;

1;

__DATA__
/*
 * <% $module_h_filename %> - This file is in the public domain
 * Author: <% $author %>
 *
 * Generated on: <% $now %>
 * <% $module_name %> version: <% $module_version %>
 */

#if !defined (<% $module_h_barrier %>)
#define <% $module_h_barrier %>

#define <% uc $c_module_name %>_C_API_REQUIRED_VERSION <% $max_version %>

void perl_<% $c_module_name %>_load(int required_version);

#define PERL_<% uc $c_module_name %>_LOAD perl_<% $c_module_name %>_load(<% uc $c_module_name %>_C_API_REQUIRED_VERSION)

extern HV *<% $c_module_name %>_c_api_hash;
extern int <% $c_module_name %>_c_api_min_version;
extern int <% $c_module_name %>_c_api_max_version;

<%
    for my $n (sort keys %function) {
        my $f = $function{$n};
        my $var = "${c_module_name}_c_api_$n";
        $OUT .= "extern $f->{type} *($var)($f->{args});\n";
        $OUT .= "#define $export_prefix$n (*$var)\n";
    }
%>

#endif
