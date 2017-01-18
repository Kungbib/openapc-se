#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
========================================================================================================================
    Script to prepare Swedish APC data files for processing
    Ulf Kronman 2017-01-05
    Adapted from and based on code by Christoph Broschinski, Copyright (c) 2016

    ToDo
    -----

    Done
    -----
    2017-01-15 Move args reading to main process
    2017-01-15 Move acronym-name mapping to reporting phase in R
    2017-01-09 Tidy up code and comment properly
    2017-01-06 Multiple file processing
    2017-01-05 Remove old code
    2017-01-05 Basic coding

========================================================================================================================
"""

import argparse
import codecs
import locale
import sys

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
STR_DATA_DIRECTORY = '../../data'

# List of institutions' files to prepare
LST_APC_FILES = [
    # 'kth/apc_kth_2015.tsv',
    # 'mah/apc_mah_2015.csv',
    # # 'slu/apc_slu_2015.csv',
    # # 'su/apc_su_2015.csv',
    # 'su/apc_su_2015.tsv',
    # 'su/apc_su_2016.csv',
]

STR_APC_FILE_LIST = STR_DATA_DIRECTORY + '/' + 'apc_file_list.txt'

# Cleaned result will be put here
STR_RESULT_FILE_NAME = STR_DATA_DIRECTORY + '/' + 'apc_se_merged.csv'

# Name mapping for institution acronyms. Move this to reporting phase in R?
DCT_CODE_NAME_MAP = {
    # 'kth': u'KTH Royal Institute of Technology',
    # 'ltu': u'Luleå Technical University',
    # 'mah': u'Malmö University College',
    # 'slu': u'Swedish University of Agricultural Sciences',
    # 'su': u'Stockholm University',
}

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

    # print 'Processing files:'
    # print LST_APC_FILES

    # A list for the cleaned data
    lst_cleaned_data = []

    # Count files to do special handling of header in first file
    int_file_number = 0

    # Fetch list of APC files to process
    lst_apc_files = []
    try:
        fp_apc_files = open(STR_APC_FILE_LIST, 'r')
        for str_line in fp_apc_files:
            lst_apc_files.append(str_line.strip())
        print 'Processing files:'
        print lst_apc_files
    except IOError:
        print 'File list not found in: {}'.format(STR_APC_FILE_LIST)
        sys.exit()

    for str_file_name in lst_apc_files:

        int_file_number += 1

        str_input_file_name = STR_DATA_DIRECTORY + '/' + str_file_name
        print '\nProcessing file {}'.format(str_input_file_name)

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

    csv_file = open(str_input_file, "r")

    reader = oat.UnicodeReader(csv_file, dialect=dialect, encoding=enc)

    first_row = reader.next()
    num_columns = len(first_row)
    print "\nCSV file has {} columns.".format(num_columns)

    csv_file.seek(0)
    reader = oat.UnicodeReader(csv_file, dialect=dialect, encoding=enc)

    print "\n    *** Starting cleaning of file *** \n"

    cleaned_content = []
    error_messages = []

    row_num = 0

    for row in reader:

        row_num += 1
        print "--- Processing line number {} ---".format(str(row_num))

        # Check input if verbose mode
        if args.verbose:
            print row

        if not row:  # Skip empty lines
            continue

        # Skip lines without content
        if not row[0].strip():
            continue

        if has_header and row_num == 1:
            header = row # First non-empty row should be the header
            cleaned_content.append(header)
            continue

        current_row = []

        col_number = 0

        # Copy content of columns
        for csv_column in row:

            col_number += 1

            # Remove leading and trailing spaces
            csv_column = csv_column.strip()

            if csv_column.lower().strip() == u'sant':
                csv_column = u'TRUE'
            elif csv_column.lower().strip() == u'falskt':
                csv_column = u'FALSE'

            # Special handling of empty APC fields
            if col_number == 3 and not csv_column:
                csv_column = u'0'

            current_row.append(csv_column)

        # Check output if verbose mode
        if args.verbose:
            print current_row

        cleaned_content.append(current_row)

    csv_file.close()

    if not error_messages:
        oat.print_g("Metadata cleaning successful, no errors occured")
    else:
        oat.print_r("There were errors during the cleaning process:\n")
        for msg in error_messages:
            print msg + "\n"

    return cleaned_content

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

# ======================================================================================================================
if __name__ == '__main__':
    main()
# ======================================================================================================================
