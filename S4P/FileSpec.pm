=head1 NAME

S4P::FileSpec.pm - Perl object implementing the FILE_SPEC part of a PDR

=head1 SYNOPSIS

=for roff
.nf

use S4P::FileSpec;
$fs = new S4P::FileSpec('text' => $text);
$path = $fs->pathname;
$fs->pathname($path);
$dirname = $fs->directory_id;
$fs->directory_id($dirname);
$filename = $fs->file_id;
$fs->file_id($filename);
$file_type = $fs->file_type;
$fs->file_type($file_type);
$file_size = $fs->file_size;
$fs->file_size($file_size);

$new_fs = $file_spec->copy;
$s = $fs->sprint([$spacious]);
$rc = $fs->checksum;

$status = $fs->status

=head1 DESCRIPTION

This object represents a FILE_SPEC, the smallest object in a Product
Delivery Record.  It mirrors the standard attributes in the PDR:
directory_id, file_id, file_type, file_size (in bytes).  In addition, 
it has a pathname attribute (concatenation of filename and directory) 
and a sprint method, which outputs the object to a string in the 
format used in a PDR.

In the strict PDR context, FILE_TYPE is SCIENCE, METADATA, PRODHIST,
BROWSE or LINKAGE.  However S4P extends this to include PCF, QA, HDF4MAP.

=over 4

=item attribute set/get routines

The following methods allow certain attributes to be set or obtained:
  pathname:  full pathname (directory_id/file_id)
  directory_id:  directory component of path
  file_id:  filename component of path
  file_type:  SCIENCE, METADATA, LINKAGE, BROWSE, PRODHIST, PCF, QA, HDF4MAP
  file_size:  size in bytes
  status: indicates the status of file
  
=item copy

Makes a copy of a FileSpec object.

=item sprint

Prints FILE_SPEC ODL to a string.
An optional argument, $spacious, specifies whether to use spaces around '='
signs.  Default is no.  
Either one can be successfully parsed by S4P modules, but the spacious form
is preferred by some interfaces, such as the ECS External Product Distributor.

=item checksum

Computes checksum according to ECS-SIPS ICD, adding to the hash values
for 'file_cksum_value' and 'file_cksum_type'.  At this time, only the
'CKSUM' type is supported.

=item verify_checksum

Checks FILE_SPEC checksum against the actual checksum, returning 0 on mismatch
As a byproduct, this updates FILE_SPEC to actual value, but that won't be a
problem if they are the same.

If no checksum is in the FILE_SPEC, it just returns 1.

=back

=head1 AUTHORS

Chris Lynnes, NASA/GSFC, Code 610.2

Daniel Ziskin, George Mason University

=head1 SEE ALSO

L<FileGroup(3)>, L<PDR(3)>

=cut

################################################################################
# FileSpec.pm,v 1.8 2011/05/18 12:49:12 glei Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

package S4P::FileSpec;
use File::Basename;
1;

sub new {
    my $pkg = shift;
    my %params = @_;

    my @attrs = qw(directory_id file_id file_type file_size completed file_cksum_type file_cksum_value status alias);
    # If text is set, parse it for a FILE_SPEC structure
    if ($params{'text'}) {
        my $text = $params{'text'};
        foreach $attr(@attrs) {
            if ($text =~ /$attr\s*=\s*(.*?);/i) { 
                $params{$attr} = $1;
            }
        }
        # Check for required fields and fail if not there
        foreach $attr('directory_id', 'file_id') {
            if (! exists $params{$attr}) {
                return undef;
            }
        }
    }
    # If pathname is set, break up into file and directory
    if ($params{'pathname'} && ! exists $params{'file_id'}) {
        $params{'file_id'} = basename $params{'pathname'}; 
        $params{'directory_id'} = dirname $params{'pathname'}; 
        delete $params{'pathname'};
    }
    my $r_filespec = \%params;
    bless $r_filespec, $pkg;
    return $r_filespec;
}
# Subroutine to copy (if we just copied references, then changing the copy
# would change the original)
sub copy {
    my $this = shift;
    my $new_fs = new S4P::FileSpec;
    %{$new_fs} = %{$this};
    return $new_fs;
}
sub pathname {
    my $this = shift;
    # Setting pathname...
    if (@_) {
        my $path = shift;

        # Find last slash in pathname
        $this->file_id(basename($path));
        if ($path =~ m#/#) {
            $this->directory_id(dirname($path));
        }
        else {
            $this->directory_id('./');
        }
        return @_;
    }
    # Getting pathname...
    else {
        # Trim trailing slash
        my $dir = $this->directory_id;
        my $file = $this->file_id;
        if ($dir && $file) {
            $dir =~ s#/$##;
            return $dir . '/' . $this->file_id;
        }
        else {
            return undef;
        }
    }
}
sub directory_id {my $this = shift; @_ ? $this->{'directory_id'} = shift
                                       : $this->{'directory_id'}}
sub file_type    {my $this = shift; @_ ? $this->{'file_type'} = shift
                                       : $this->{'file_type'}}
sub file_size    {my $this = shift; @_ ? $this->{'file_size'} = shift
                                       : $this->{'file_size'}}
sub completed    {my $this = shift; @_ ? $this->{'completed'} = shift
                                       : $this->{'completed'}}
sub alias        {my $this = shift; @_ ? $this->{'alias'} = shift
                                       : $this->{'alias'}}

sub file_id {
    my $this = shift; 
    local($pathfile)=@_;
    local ($file);
    if ($pathfile) {
        @parts=split(/\//,$pathfile);
        $n=@parts;
        $this->{'file_id'} = $parts[$n-1];
    }
    else {
        $this->{'file_id'};
    }
}


sub sprint {
    use strict;
    my $this = shift;
    my $spacious = shift;
    my $format = ($spacious) ? "\t\t%s = %s\;\n" : "\t\t%s=%s\;\n";
    my $object_tag = ($spacious) ? "OBJECT = FILE_SPEC\;\n" : "OBJECT=FILE_SPEC\;\n";

    my $text = sprintf("\t%s", $object_tag);
    foreach my $attr (keys %{$this}) {
        next if ($attr =~ /text/);
        my $ATTR=uc($attr);
        $text.=sprintf($format, $ATTR, $this->{$attr});
    }
    $text .= sprintf("\tEND_%s", $object_tag);
    return $text;
}

sub guess_file_type {
    my $f = shift;

    # Can be called as instance method or class method
    $file = (ref $f) ? $f->file_id : $f;  

    my $type;
    if ($file =~ /\.pcf$/) {
        $type = 'PCF';
    }
    elsif ($file =~ /\.(met|xml)$/i) {
        $type = 'METADATA';
    }
    elsif ($file =~ /\b(PH|ProductionHistory).*\.tar$/i) {
        $type = 'PRODHIST';
    }
    elsif ($file =~ /LINK.*\.(lnk|pvl)$/i) {
        $type = 'LINKAGE';
    }
    elsif ($file =~ /Browse\..*\.hdf$/i || $file =~ /\.BRO(\.Z)?$/i ||
           $file =~ /\.(jpg|jpeg)$/i ) {
        $type = 'BROWSE';
    }
    else {
        $type = 'SCIENCE';
    }
    $f->file_type($type) if ($type && ref $f);
    return $type;
}

# $fs->checksum()
sub checksum {
    my $this = shift;

    # Get pathname of file to checksum
    my $path = $this->pathname;
    unless ($path) {
        warn "S4P::FileSpec::Checksum: No path found in file_spec object";
        return 0;
    }
    unless (-f $path) {
        warn "S4P::FileSpec::Checksum: pathname $path not found";
        return 0;
    }

    # Compute checksum using system command
    my $checksum_text = "";
    my $cksum_type = "CKSUM";
    if (exists($this->{file_cksum_type}) and uc($this->{file_cksum_type}) eq "MD5") {
        $checksum_text = `md5sum $path`;
        $cksum_type = "MD5";
    } else {
        $checksum_text = `cksum $path`;
    }
    if ($?) {
        warn "S4P::FileSpec::Checksum: Error computing checksum";
        return 0;
    }
    my ($checksum, $size) = split(' ', $checksum_text);

    # Ignore size as MD5 does not return size

    $this->{'file_cksum_value'} = $checksum;
    $this->{'file_cksum_type'} = $cksum_type;
    return $checksum;
}

sub verify_checksum {
    use strict;
    my $this = shift;

    return 1 unless (exists $this->{'file_cksum_value'});

    # Save off checksum in FILE_SPEC (since checksum() will overwrite)
    my $assertion = $this->{'file_cksum_value'};

    # Recompute checksum
    my $actual = $this->checksum();

    # Compare checksums using strings (to account for MD5)
    if ($this->{'file_cksum_value'} ne $assertion) {
        warn ( "ERROR: Checksum verification failed for " 
                . $this->pathname() . "\n"
                . "Checksum (type " . $this->{'file_cksum_type'}
                . ") in PDR is $assertion; actual is $actual\n" );
        return 0;
    }
    return 1;
}

# $fs->status
sub status {
    my ( $this, $status ) = @_;
    $this->{'status'} = $status if defined $status;
    return (defined $this->{'status'} ? $this->{'status'} : undef);
}
