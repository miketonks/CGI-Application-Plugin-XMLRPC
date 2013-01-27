CGI-Application-Plugin-XMLRPC
=============================

Simple XMLRPC Server using CGI::Application.  Optional forking handler for background processing.

Usage:

sub my_xmlrpc_method
{
  my $self = shift;

  my $xml_input = $self->xmlrpc_params();

  # Log our call
  warn 'Called with: ' . Dumper($xml_input);

  my $id 	  = $xml_input->{ID};

  # Must have a trigger id
  return $self->fault(1001, 'ID is a required field') unless $id;

  if ($self->fork_process()) {

    # parent thread
    warn "Returning 200 status to the caller";

    # Ensure we return to caller
    return $self->result(200, 'OK');
  }

  # continue processing with child thread
  warn "Child thread running - continue with background processing");

  sleep 20;

  warn "the end';

  exit 0;
}
