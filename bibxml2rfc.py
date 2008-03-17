#!/usr/bin/python
# Build a bibliography for an xml2rfc input file
#
# Eric Rescorla <ekr@rtfm.com>
#
# Copyright (C) 2008 RTFM, Inc. 200

import sys
import getopt
import urllib2
from xml.dom.minidom import parse, parseString;
from os.path import exists, dirname, abspath, isdir
from os import mkdir


# Constants
REFDIR="references"
REF_RFC_URI_PREFIX="http://xml.resource.org/public/rfc/bibxml/reference.RFC."
REF_ID_URI_PREFIX="http://xml.resource.org/public/rfc/bibxml3/reference."


def usage():
    sys.stderr.write("usage: bibxml2rfc [-vi] filename\n\
    -v verbose\n\
    -i fake entries for IETF documents\n")
    sys.exit(1)


def get_reference(name,cachefile):
    report("Getting reference "+name+" (cachefile="+cachefile+")")

    cached = None
    # Look in the cache
    report("Checking cache")
    if exists(cachefile):
        report("Already in cache")
        fh = open(cachefile,'r')
        cached=fh.read()

    if name.startswith("I-D."):
        # Internet Draft
        # There may be new versions so need to check the net
        uri=REF_ID_URI_PREFIX + name + ".xml"
    elif name.startswith("RFC"):
        # RFC
        # RFCs never change
        if cached != None:
            return cached
        uri=REF_RFC_URI_PREFIX + name[3:] + ".xml"
    else:
        # Something unknown. Don't know how to fetch
        return cached

    try:
        report("Trying to fetch uri "+uri)
        fh = urllib2.urlopen(uri)
        res = fh.read()
        fh.close()
    except Exception:
        warning("Could not fetch target "+target+" (url="+uri+")")
        if cached != None:
            report("Using cached value")
            return cached
        
        if fake_ietf_entries == True:
            report("Faking entry for "+target)
            res = '<reference anchor="'+target+'">\n' + '<front><title>Fake Entry</title>\n'+'<author initials="F." surname="Author" fullname="Fake Author"/>\n'+ '<date year="2000"/>\n'+ '</front>\n'+ '<seriesInfo name="Fake" value="Series"/>\n'+ '</reference>\n'
            return res
        else:
            return None

    # OK, we have the file. Now open the cachefile and store it there
    report("Successfully fetched "+target)
    fh = open(cachefile, 'w')
    fh.write(res)
    fh.close()
    return res

def warning(a):
    sys.stderr.write(a+"\n")

def report(a):
    if verbose == True:
        sys.stdout.write(a+"\n")
def opt_isset(opts,flag):
    for opt in opts:
        if opt[0] == flag:
            return True
    
# Control parameters
verbose = False
fake_ietf_entries = True

# Read the command line arguments
getopt_out=getopt.getopt(sys.argv[1:],"vi")
options=getopt_out[0]

if opt_isset(options,'-v'):
    verbose=True
if opt_isset(options,'-i'):
    fake_ietf_entries=True

arguments=getopt_out[1]
if len(arguments)!=1:
    usage()
filename=arguments[0]
if exists(filename)!=True:
    sys.stderr.write("File "+filename+" does not exist\n")
    sys.exit(1)
filedir=dirname(abspath(filename))

# If the references directory does not exist, make it
refdir = filedir + '/' + REFDIR
if isdir(refdir)==False:
    mkdir(refdir)

# OK, now parse the file
dom1 = parse(filename)
xrefs = dom1.getElementsByTagName("xref")

# Open the files to write to
f_normative = open(filename + "-normative","w")
f_informative = open(filename + "-informative","w")

reference_out={};
reference_body={};

# Find all the references
for xref in xrefs:
    target = xref.getAttribute("target")
    norm = xref.getAttribute("norm").lower()

    # Figure out what kind of reference it is
    if norm == "":
        normative=f_informative
    elif norm == "true":
        normative=f_normative
    elif norm == "false":
        normative=f_informative
    else:
        sys.stderr.write("Unknown 'norm' value '"+norm+"' for target '"+target+"'. Assuming informative.\n")

    cachefile = refdir + "/" + target + ".xml"

    ref_body = get_reference(target, cachefile)
    if ref_body != None:
        """
         Add this reference if it's not already listed
         If it is already listed but as informative and defined
         here as normative, then override it"""
        
        if reference_out.has_key(target)==False:
            reference_out[target]=normative
            reference_body[target]=ref_body
        else:
            if reference_out[target]==f_informative and normative==True:
                reference_out[target]=f_normative
                

# Now write out the reference sections
for key in reference_out.keys():
    reference_out[key].write("\n\n")
    reference_out[key].write(reference_body[key])
    
    
    
    
        

    
    
