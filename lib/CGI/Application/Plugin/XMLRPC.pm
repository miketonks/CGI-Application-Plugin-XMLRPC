
package CGI::Application::Plugin::XMLRPC;

use strict;

use Carp;
use Data::Dumper;
use Encode;
use Frontier::RPC2;
use Try::Tiny;

#use vars qw($VERSION @EXPORT);

use Exporter;

our $VERSION = '0.1';

our @ISA = qw(Exporter);

#our @EXPORT = qw(read_request_xml);

sub import
{
    my $pkg     = shift;
    my $callpkg = caller;

    # Do our own exporting. (copied from CAP::Routes
    {
        no strict qw(refs);
        *{ $callpkg . '::coder' } = \&CGI::Application::Plugin::XMLRPC::coder;
        *{ $callpkg . '::read_request_xml' } = \&CGI::Application::Plugin::XMLRPC::read_request_xml;
        *{ $callpkg . '::xmlrpc_params' } = \&CGI::Application::Plugin::XMLRPC::xmlrpc_params;
        *{ $callpkg . '::xmlrpc_fault' } = \&CGI::Application::Plugin::XMLRPC::xmlrpc_fault;
    }

    if ( ! UNIVERSAL::isa($callpkg, 'CGI::Application') ) {
        warn "Calling package is not a CGI::Application module so not setting up the prerun hook.  If you are using \@ISA instead of 'use base', make sure it is in a BEGIN { } block, and make sure these statements appear before the plugin is loaded";
    } else {
        $callpkg->add_callback( prerun => \&prerun_callback );
        $callpkg->add_callback( postrun => \&postrun_callback );
        goto &Exporter::import;
    }
}


sub prerun_callback
{
	my $self = shift;

	$self->run_modes([qw/xmlrpc_fault/]);

	my $method = $self->query->request_method();

    # Perform some sanity checks.
    unless ($method eq "POST") {

    	#$self->{http_error} = [405, "Method $method Not Allowed"];
    	#return $self->http_error('fault');

		$self->{'CAP::XMLRPC::FAULT'} = "Method $method Not Allowed";
		$self->prerun_mode('xmlrpc_fault');
		return;
    }

	my $request = $self->read_request_xml();

	my $rm = $request->{method_name};

	my $run_modes = {($self->run_modes())};

	if (exists($run_modes->{$rm})) {

		$self->prerun_mode($rm);
	}
	elsif (exists($run_modes->{'AUTOLOAD'})) {

		$self->prerun_mode($run_modes->{'AUTOLOAD'});
	}
	else {

		$self->{'CAP::XMLRPC::FAULT'} = "No such method '$rm'";
		$self->prerun_mode('xmlrpc_fault');
	}
}

sub postrun_callback
{
	my $self = shift;
	my $content = shift;

	$self->header_add(-type 	=> 'text/xml');

	# Replace old output with new output
	$$content = $self->coder->encode_response($$content);

	$logger->trace("RESPONSE_XML: $$content");
}


sub read_request_xml
{
	my $self = shift;

	my $request_xml = $self->query->param("POSTDATA");

	if (!$request_xml) {

		$self->{'CAP::XMLRPC::FAULT'} = [500, "error decoding RPC"];
		return { method_name => 'xmlrpc_fault' };
	}

	# FIXME bug in Frontier's XML
	$request_xml =~ s/(<\?XML\s+VERSION)/\L$1\E/;

	my $request;

	try {

		$request = $self->coder->decode($request_xml);
	}
	catch {

		warn "error decoding RPC: $_";
	};

	unless ($request) {

		$self->{'CAP::XMLRPC::FAULT'} = [500, "Unable to decode XMLRPC request"];
		return { method_name => 'xmlrpc_fault' } ;
	}

	$self->{request} = $request; # save it for later

	if ($request->{'type'} eq 'call') {

		return $request;
    }
    else {

		warn "expected RPC \`methodCall', got \`$request->{'type'}'";

		$self->{'CAP::XMLRPC::FAULT'} = [2, "expected RPC \`methodCall', got \`$request->{'type'}'\n"];
		return { method_name => 'xmlrpc_fault' };;
	}
}

sub coder
{
	my $self = shift;

	my $coder =	$self->{'CAP::XMLRPC::CODER'};

	unless (defined $coder) {

		$coder = Frontier::RPC2->new();

		$self->{'CAP::XMLRPC::CODER'} = $coder;
	}

	return $coder;
}

sub xmlrpc_params
{
	my $self = shift;

	if (wantarray) {

		return @{$self->{request}->{value}};
	}
	else {

		return $self->{request}->{value}->[0];
	}
}

sub xmlrpc_fault
{
	my $self = shift;

	$logger->debug("FAULT: " . Dumper($self->{'CAP::XMLRPC::FAULT'}));

	return $self->{'CAP::XMLRPC::FAULT'};
}

#sub http_error
#{
#	my $self = shift;
#	return "<h1>HTTP Error</h1>";
#}

1;

