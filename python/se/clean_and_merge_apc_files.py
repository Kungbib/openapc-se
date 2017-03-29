#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
========================================================================================================================
    Script to prepare Swedish APC data files for processing
    Ulf Kronman 2017-01-05
    Adapted from and based on code by Christoph Broschinski, Copyright (c) 2016

    ToDo
    -----
    Add parameter to process a single file
    Do publisher normalisation here before Crossref enrichment?
    Handle duplicate entries by skipping second entry and reporting for submission to data supplier
    Report DOI errors to file(?) for correction by institutions

    Done
    -----
    2017-03-16 Handle # comments for duplicates
    2017-03-02 Add (temporary?) function to comment away files from file list
    2017-02-16 Remove erroueous zero for non-cost entries?
    2017-02-26 Check for duplicate entries on DOI
    2017-02-15 Substitute comma for period
    2017-02-14 Re-code for only pre-processing

========================================================================================================================
"""

import argparse
import codecs
import locale
import sys
import urllib2
import xml.etree.ElementTree as ET

# Add path for script environment
# sys.path.append('/Users/ulfkro/OneDrive/KB-dokument/Open Access/Kostnader/Open APC Sweden/openapc-se')
sys.path.append('/Users/ulfkro/OneDrive/KB-dokument/Open Access/Kostnader/Open APC Sweden/openapc-se_development')

import python.openapc_toolkit as oat


# Global parameters
# ======================================================================================================================

ARG_HELP_STRINGS = {
    "encoding": "The encoding of the CSV file. Setting this argument will " +
                "disable automatic guessing of encoding.",
    "locale": "Set the locale context used by the script. You might want to " +
              "set this if your system locale differs from the locale the " +
              "CSV file was created in (Example: Using en_US as your system " +
              "locale might become a problem if the file contains numeric " +
              "values with ',' as decimal mark character)",
    "headers": "Ignore any CSV headers (if present) and try to determine " +
               "relevant columns heuristically.",
    "verbose": "Be more verbose during the cleaning process.",
}

ERROR_MSGS = {
    "locale": "Error: Could not process the monetary value '{}' in column " +
              "{}. This will usually have one of two reasons:\n1) The value " +
              "does not represent a number.\n2) The value represents a " +
              "number, but its format differs from your current system " +
              "locale - the most common source of error will be the decimal " +
              "mark (1234.56 vs 1234,56). Try using another locale with the " +
              "-l option."
}

# Where do we find and put the data
STR_DATA_DIRECTORY = '../../data/'

STR_APC_FILE_LIST = STR_DATA_DIRECTORY + 'apc_file_list.txt'

# Cleaned result will be put here
STR_RESULT_FILE_NAME = STR_DATA_DIRECTORY + 'apc_se_merged.tsv'

# Keep a list of processed DOI's to check for duplicates - what to do if found?
lst_dois_processed = []

# ======================================================================================================================


# ======================================================================================================================
def main():
    """ The main processing of data """

    # Read data from the raw APC files
    lst_cleaned_data = collect_apc_data()

    # Write cleaned data to summary file
    write_cleaned_data(lst_cleaned_data)

# ======================================================================================================================


# Gather data from the delivered APC files
# ======================================================================================================================
def collect_apc_data():
    """ Method to collect data from institions suppliced CSV or TSV files """

    parser = argparse.ArgumentParser()
    # parser.add_argument("csv_file", help=ARG_HELP_STRINGS["csv_file"])
    parser.add_argument("-e", "--encoding", help=ARG_HELP_STRINGS["encoding"])
    parser.add_argument("-v", "--verbose", action="store_true",
                        help=ARG_HELP_STRINGS["verbose"])
    parser.add_argument("-l", "--locale", help=ARG_HELP_STRINGS["locale"])
    parser.add_argument("-i", "--ignore-header", action="store_true",
                        help=ARG_HELP_STRINGS["headers"])

    args = parser.parse_args()

    # A list for the cleaned data
    lst_cleaned_data = []

    # Count files to do special handling of header in first file
    int_file_number = 0

    # Fetch list of APC files to process
    lst_apc_files = []
    try:
        fp_apc_files = open(STR_APC_FILE_LIST, 'r')
        print '--------------------------------------'
        print 'Processing files:' # {}'.format('; '.join(lst_apc_files))
        for str_line in fp_apc_files:
            # Don't process if we have a comment (#) on the line
            if '#' in str_line:
                continue
            lst_apc_files.append(str_line.strip())
            print str_line.strip()
        print '--------------------------------------'
    except IOError:
        print 'File list not found in: {}'.format(STR_APC_FILE_LIST)
        sys.exit()

    for str_file_name in lst_apc_files:

        int_file_number += 1

        print 'Processing file: {} \n==================================================== \n'.format(str_file_name)

        str_input_file_name = STR_DATA_DIRECTORY + '/' + str_file_name
        lst_new_apc_data = clean_apc_data(str_input_file_name, args)

        if int_file_number == 1:
            lst_cleaned_data.extend(lst_new_apc_data)
        else:
            int_row_number = 0
            for lst_row in lst_new_apc_data:
                int_row_number += 1
                if int_row_number == 1:
                    continue
                else:
                    lst_cleaned_data.append(lst_row)

    return lst_cleaned_data

# ======================================================================================================================


# ======================================================================================================================
def write_cleaned_data(cleaned_content):

    print 'INFO: Writing result to file {}'.format(STR_RESULT_FILE_NAME)

    with open(STR_RESULT_FILE_NAME, 'w') as out:

        for lst_line in cleaned_content:
            # print lst_line
            if lst_line:
                out.write(u'\t'.join(lst_line).encode("utf-8"))
                out.write(u'\n')

# ======================================================================================================================


# ======================================================================================================================
def clean_apc_data(str_input_file, args):
    """ Process APC file """

    enc = None # CSV file encoding

    if args.locale:
        norm = locale.normalize(args.locale)
        if norm != args.locale:
            print "locale '{}' not found, normalized to '{}'".format(
                args.locale, norm)
        try:
            loc = locale.setlocale(locale.LC_ALL, norm)
            print "Using locale", loc
        except locale.Error as loce:
            print "Setting locale to " + norm + " failed: " + loce.message
            sys.exit()

    if args.encoding:
        try:
            codec = codecs.lookup(args.encoding)
            print ("Encoding '{}' found in Python's codec collection " +
                   "as '{}'").format(args.encoding, codec.name)
            enc = args.encoding
        except LookupError:
            print ("Error: '" + args.encoding + "' not found Python's " +
                   "codec collection. Either look for a valid name here " +
                   "(https://docs.python.org/2/library/codecs.html#standard-" +
                   "encodings) or omit this argument to enable automated " +
                   "guessing.")
            sys.exit()

    # Read file data into result dictionary object
    result = oat.analyze_csv_file(str_input_file)

    if result["success"]:
        csv_analysis = result["data"]
        print csv_analysis
    else:
        print result["error_msg"]
        sys.exit()
    
    if enc is None:
        enc = csv_analysis.enc
    dialect = csv_analysis.dialect
    has_header = csv_analysis.has_header

    if enc is None:
        print ("Error: No encoding given for CSV file and automated " +
               "detection failed. Please set the encoding manually via the " +
               "--enc argument")
        sys.exit()

    print '\nProcessing file {}'.format(str_input_file)
    csv_file = open(str_input_file, "r")

    reader = oat.UnicodeReader(csv_file, dialect=dialect, encoding=enc)

    first_row = reader.next()
    num_columns = len(first_row)
    print "\nCSV file has {} columns.".format(num_columns)

    csv_file.seek(0)
    reader = oat.UnicodeReader(csv_file, dialect=dialect, encoding=enc)

    print "\nNOTE:    *** Starting cleaning of file *** \n"

    cleaned_content = []
    error_messages = []

    row_num = 0

    for row in reader:

        row_num += 1

        # print "--- Processing line number {} ---".format(str(row_num))

        # Check input if verbose mode
        if args.verbose:
            print row

        # Skip empty lines
        if not row:
            continue

        # Skip lines without content
        if not row[0].strip():
            continue

        # Skip lines with comment sign # in first position
        if row[0] == '#':
            continue

        # Skip record if empty APC field
        if not row[3].strip():
            print '!Warning: No APC given for publication {}. Skipping entry.'.format(row[4])
            continue

        # First non-empty row should be the header
        if has_header and row_num == 1:
            header = row
            cleaned_content.append(header)
            continue

        # Put the DOI in a string for later use
        if row[3]:
            str_doi = row[3].strip()
        else:
            print 'WARNING: No DOI found'
            str_doi = ''

        current_row = []

        col_number = 0

        # Copy content of columns
        for csv_column in row:

            col_number += 1

            # Remove leading and trailing spaces
            csv_column = csv_column.strip()

            if csv_column.lower() == u'sant':
                csv_column = u'TRUE'
            elif csv_column.lower() == u'falskt':
                csv_column = u'FALSE'
            elif csv_column == u'true':
                csv_column = u'TRUE'
            elif csv_column == u'false':
                csv_column = u'FALSE'

            # Handling of APC column
            if col_number == 3:

                # print csv_column

                # Clean monetary Euro column from spaces due to formatting
                csv_column = ''.join(csv_column.split())

                # Change commas to periods
                csv_column = csv_column.replace(",", ".")

                # print csv_column

            # Check for DOI duplicates
            if col_number == 4:
                pass
                if csv_column in lst_dois_processed:
                    print '!Error duplicate DOI {} - Org: {} - Year: {} '.format(
                        csv_column, row[0], row[1]
                    )
                    sys.exit()
                else:
                    lst_dois_processed.append(csv_column)

            current_row.append(csv_column)

        # Check output if verbose mode
        if args.verbose:
            print current_row

        cleaned_content.append(current_row)

    csv_file.close()

    if not error_messages:
        oat.print_g("Metadata cleaning successful, no errors occured\n")
    else:
        oat.print_r("There were errors during the cleaning process:\n")
        for msg in error_messages:
            print msg + "\n"

    # Write new publisher names to file
    # obj_publisher_normaliser.write_new_name_map()

    return cleaned_content

# ======================================================================================================================


# ======================================================================================================================
class XPublisherNormaliser(object):
    """ Class to keep data and methods for publisher name normalisation """

    STR_PUBLISHER_NAME_MAP_FILE = STR_DATA_DIRECTORY + '/' + 'publisher_name_map.tsv'

    # ------------------------------------------------------------------------------------------------------------------
    def __init__(self):
        """ Create name mapping dictionary for processing """
        self.dct_publisher_name_map = {}
        fp_publisher_map = open(self.STR_PUBLISHER_NAME_MAP_FILE, 'r')
        for str_row in fp_publisher_map:
            lst_row = str_row.split('\t')
            self.dct_publisher_name_map[lst_row[0].lower()] = lst_row[1].strip()
        fp_publisher_map.close()
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def normalise(self, str_publisher_name_in, str_doi):
        """ The main procedure to look up publisher name in name map and CrossRef. Calls sub-methods. """
        # Check if we already have this name in the map
        str_publisher_name_lower = str_publisher_name_in.strip().lower()
        if str_publisher_name_lower in self.dct_publisher_name_map.keys():
            str_publisher_name_normalised = self.dct_publisher_name_map[str_publisher_name_lower]
            if str_publisher_name_normalised != str_publisher_name_in:
                print 'NOTE: Name "{}" normalised to "{}"'.format(str_publisher_name_in, str_publisher_name_normalised)
            return str_publisher_name_normalised
        elif str_doi:
            # Look up in CrossRef
            tpl_crossref_result = self.get_crossref_names(str_doi)
            str_publisher_name_normalised = self.ask_user(str_publisher_name_in, tpl_crossref_result)
            return str_publisher_name_normalised
        else:
            print 'WARNING: No normalisation of name {}'.format(str_publisher_name_in)
            return str_publisher_name_in
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def ask_user(self, str_publisher_name_in, tpl_crossref_result):
        """ Ask opinion from user and return choice """
        print 'NOTE: Several name choices found. Please chose one alternative or enter new suggested name'
        print '1) {}'.format(str_publisher_name_in)
        print '2) {}'.format(tpl_crossref_result[0])
        print '3) {}'.format(tpl_crossref_result[1])
        print '4) Enter new preferred name'
        str_choice = raw_input('Choose [2] or enter new name:  ')
        if str_choice == '1':
            str_publisher_name_normalised = str_publisher_name_in
        elif str_choice == '2':
            str_publisher_name_normalised = tpl_crossref_result[0]
        elif str_choice == '3':
            str_publisher_name_normalised = tpl_crossref_result[1]
        elif str_choice:
            str_publisher_name_normalised = str_choice
        else:
            str_publisher_name_normalised = tpl_crossref_result[0]
        # Add choice to mapping dictionary
        self.dct_publisher_name_map[str_publisher_name_in.lower()] = str_publisher_name_normalised
        return str_publisher_name_normalised
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def write_new_name_map(self):
        """ Write the new name map to file to remember for next processing """
        fp_name_map_file = open(self.STR_PUBLISHER_NAME_MAP_FILE, 'w')
        for str_key in self.dct_publisher_name_map.keys():
            fp_name_map_file.write('{}\t{}\n'.format(str_key, self.dct_publisher_name_map[str_key]))
        fp_name_map_file.close()
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def get_crossref_names(self, doi):
        """ Get Crossref info
            <crm-item name="publisher-name" type="string">Institute of Electrical and Electronics Engineers (IEEE)</crm-item>
            <crm-item name="prefix-name" type="string">Institute of Electrical and Electronics Engineers</crm-item>
        """
        url = 'http://data.crossref.org/' + doi
        headers = {"Accept": "application/vnd.crossref.unixsd+xml"}
        req = urllib2.Request(url, None, headers)
        try:
            response = urllib2.urlopen(req)
            content_string = response.read()
            root = ET.fromstring(content_string)
            # print content_string
            prefix_name_result = root.findall(".//cr_qr:crm-item[@name='prefix-name']",
                                  {"cr_qr": "http://www.crossref.org/qrschema/3.0"})
            publisher_name_result = root.findall(".//cr_qr:crm-item[@name='publisher-name']",
                                  {"cr_qr": "http://www.crossref.org/qrschema/3.0"})
            return publisher_name_result[0].text, prefix_name_result[0].text
        except urllib2.HTTPError as httpe:
            code = str(httpe.getcode())
            return "HTTPError: {} - {}".format(code, httpe.reason)
        except urllib2.URLError as urle:
            return "URLError: {}".format(urle.reason)
        except ET.ParseError as etpe:
            return "ElementTree ParseError: {}".format(str(etpe))
    # ------------------------------------------------------------------------------------------------------------------

# ======================================================================================================================


# ======================================================================================================================
class CSVColumn(object):
    MANDATORY = "mandatory"
    OPTIONAL = "optional"
    NONE = "non-required"

    OW_ALWAYS = 0
    OW_ASK = 1
    OW_NEVER = 2

    _OW_MSG = (u"\033[91mConflict\033[0m: Existing non-NA value " +
               u"\033[93m{ov}\033[0m in column \033[93m{name}\033[0m is to be " +
               u"replaced by new value \033[93m{nv}\033[0m.\nAllow overwrite?\n" +
               u"1) Yes\n2) Yes, and always replace \033[93m{ov}\033[0m by " +
               "\033[93m{nv}\033[0m in this column\n3) Yes, and always " +
               "overwrite in this column\n4) No\n5) No, and never replace " +
               "\033[93m{ov}\033[0m by \033[93m{nv}\033[0m in this " +
               "column\n6) No, and never overwrite in this column\n>")

    # ------------------------------------------------------------------------------------------------------------------
    def __init__(self, column_type, requirement, index=None, column_name="", overwrite=OW_ASK):
        self.column_type = column_type
        self.requirement = requirement
        self.index = index
        self.column_name = column_name
        self.overwrite = overwrite
        self.overwrite_whitelist = {}
        self.overwrite_blacklist = {}
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def check_overwrite(self, old_value, new_value):
        if old_value == new_value:
            return old_value
        # Priority: Empty or NA values will always be overwritten.
        if old_value == "NA":
            return new_value
        if old_value.strip() == "":
            return new_value
        if self.overwrite == CSVColumn.OW_ALWAYS:
            return new_value
        if self.overwrite == CSVColumn.OW_NEVER:
            return old_value
        if old_value in self.overwrite_blacklist:
            if self.overwrite_blacklist[old_value] == new_value:
                return old_value
        if old_value in self.overwrite_whitelist:
            return new_value
        msg = CSVColumn._OW_MSG.format(ov=old_value, name=self.column_name,
                                       nv=new_value)
        msg = msg.encode("utf-8")
        ret = raw_input(msg)
        while ret not in ["1", "2", "3", "4", "5", "6"]:
            ret = raw_input("Please select a number between 1 and 5:")
        if ret == "1":
            return new_value
        if ret == "2":
            self.overwrite_whitelist[old_value] = new_value
            return new_value
        if ret == "3":
            self.overwrite = CSVColumn.OW_ALWAYS
            return new_value
        if ret == "4":
            return old_value
        if ret == "5":
            self.overwrite_blacklist[old_value] = new_value
            return old_value
        if ret == "6":
            self.overwrite = CSVColumn.OW_NEVER
            return old_value
    # ------------------------------------------------------------------------------------------------------------------

# ======================================================================================================================

# Invoke the main loop
# ======================================================================================================================
if __name__ == '__main__':
    main()
# ======================================================================================================================
