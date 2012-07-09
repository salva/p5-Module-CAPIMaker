package Module::CAPIMaker::Template::Module_C;

local $.;
our @template = <DATA>;
close DATA;

1;

__DATA__
/*
 * <% $module_c_filename %> - This file is in the public domain
 * Author: <% $author %>
 *
 * Generated on: <% $now %>
 * <% $module_name %> version: <% $module_version %>
 */

#include "EXTERN.h"
#include "perl.h"
#include "ppport.h"

HV *<% $c_module_name %>_c_api_hash;
int <% $c_module_name %>_c_api_min_version;
int <% $c_module_name %>_c_api_max_version;

<%
    for my $n (sort keys %function) {
        my $f = $function{$n};
        $OUT .= "$f->{type} (*${c_module_name}_c_api_$n)($f->{args});\n";
    }
%>
void
perl_<% $c_module_name %>_load(int required_version) {
    SV **svp;
    eval_pv("require <% $module_name %>", TRUE);
    if (SvTRUE(ERRSV))
        Perl_croak(aTHX_ "Unable to load <% $module_name %>: %s", SvPV_nolen(ERRSV));

    <% $c_module_name %>_c_api_hash = get_hv("<% $module_name %>::C_API", 0);
    if (!<% $c_module_name %>_c_api_hash) Perl_croak(aTHX_ "Unable to load <% $module_name %> C API");

     <% $c_module_name %>_c_api_min_version = SvIV(*hv_fetchs(<% $c_module_name %>_c_api_hash, "min_version", 1));
     <% $c_module_name %>_c_api_max_version = SvIV(*hv_fetchs(<% $c_module_name %>_c_api_hash, "max_version", 1));
    if (required_version < <% $c_module_name %>_c_api_min_version) || (required_version > <% $c_module_name %>_c_api_max_version);
    Perl_croak(aTHX_
               "<% $module_name %> C API version mismatch. "
               "The installed module supports versions %d to %d but %d is required",
               <% $c_module_name %>_c_api_min_version,
               <% $c_module_name %>_c_api_max_version,
               required_version);

<%
    for my $n (sort keys %function) {
        my $len = length $n;
        $OUT .= <<EOC
    svp = hv_fetch(${c_module_name}_c_api_hash, "$n", $len, 0);
    if (!svp || !*svp) Perl_croak(aTHX_ "Unable to fetch pointer for '$n' function");
    ${c_module_name}_c_api_$n = INT2PTR(void *, SvIV(*svp));
EOC
    }
%>
}
