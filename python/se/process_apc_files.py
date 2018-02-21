#!C:/python27/python
# -*- coding: utf-8 -*-
"""
========================================================================================================================
    Script to prepare and process Swedish APC data files
    Ulf Kronman 2017-04-06--08-04
    Adapted from and based on code by Christoph Broschinski, Copyright (c) 2016

    ToDo
    -----
    Fix todos
    Shebang options for multiple environments (chl).
    Handle duplicate entries by skipping second entry and reporting for submission to data supplier
    Future: Clean up processing logic and introduce error handling - Error reporting module?
    Future: Add APC records to Django SwePub database - separate class/module?
    Future: Report DOI errors to file(?) for correction by institutions

    Done
    -----
    2017-09-08 Read DOIs and data from final master to avoid processing of already processed entries
    2017-09-07 Handle this DOI error with invisble blanks:
            slu	2015	2064.46	10.​1105/​tpc.​114.​134494	SANT	American Society of Plant Biologists
    2017-09-06 Add DOI correction subroutine for the following:
            0.1186/s12864-015-1829-1 ----> 10.1186/s12864-015-1829-1
    2017-08-04 Exclude duplicate DOI checking on empty field = 'NA'
    2017-08-03 Script does not handle empty DOI properly - fix it
    2017-08-03 Run LTU test file through the system
    2017-07-26 Fix IDE-marked issues
    2017-05-19 Handling of duplicate DOI's
    2017-05-22 Handle files with only 6 mandatory fields
    2017-05-19 Run new SLU records
    2017-05-22 Handle commented lines in TSV input files
    2017-05-22 Handle files with only 6 mandatory fields
    2017-05-10 Run DU's records
    2017-04-11 Add final normalisation of master file before saving
    2017-04-11 Add header line to apc_se.csv output and remove header line from added data
    2017-04-07 Re-code for complete process for one APC file at a time
    2017-04-07 Do publisher normalisation here before Crossref enrichment?

========================================================================================================================
"""

# from __future__ import unicode_literals
from __future__ import division

import argparse
import codecs
import locale
import sys
import platform
import urllib2
import xml.etree.ElementTree as ElementTree
from subprocess import call
from openpyxl import load_workbook
from shutil import copyfile #chl
import unicodecsv as csv
import time

# Add path for script environment
# sys.path.append('/Users/ulfkro/OneDrive/KB-dokument/Open Access/Kostnader/Open APC Sweden/openapc-se')
if platform.system() == 'Windows':
    sys.path.append('C:/Users/camlin/system/openapc-se')
elif platform.system() == 'Darwin':
    if '/Users/ulfkro/system/swepub' not in sys.path:
        sys.path.append('/Users/ulfkro/OneDrive/KB-dokument/Open Access/Kostnader/Open APC Sweden/openapc-se_development')

import python.openapc_toolkit as oat


# ======================================================================================================================
class Config(object):
    """ Keep configuration parameters and processes here to hide clutter from main """

    BOOL_VERBOSE = False
    INT_REPORT_WAIT = 10

    # Where do we find and put the data
    STR_DATA_DIRECTORY = '../../data/'

    STR_APC_FILE_LIST = STR_DATA_DIRECTORY + 'apc_file_list.txt'

    STR_APC_SE_FILE = '../../data/apc_se.csv'

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

    # # Keep a list of processed DOI's to check for duplicates - what to do if found?
    # lst_dois_processed = []

    # ------------------------------------------------------------------------------------------------------------------
    @staticmethod
    def get_arguments(self):

        parser = argparse.ArgumentParser()
        # parser.add_argument("csv_file", help=self.ARG_HELP_STRINGS["csv_file"])
        parser.add_argument("-e", "--encoding", help=self.ARG_HELP_STRINGS["encoding"])
        parser.add_argument("-v", "--verbose", action="store_true",
                            help=self.ARG_HELP_STRINGS["verbose"])
        parser.add_argument("-l", "--locale", help=self.ARG_HELP_STRINGS["locale"])
        parser.add_argument("-i", "--ignore-header", action="store_true",
                            help=self.ARG_HELP_STRINGS["headers"])

        args = parser.parse_args()

        # If we have a request for verbose processing set config parameter to True
        if args.verbose:
            self.BOOL_VERBOSE = True

        return args
    # ------------------------------------------------------------------------------------------------------------------

# ======================================================================================================================


# ======================================================================================================================
def main():
    """ The main processing of data """

    # Create a configuration object for easier processing
    # obj_config = Config()
    # Get line arguments
    # args = obj_config.get_arguments()
    args = Config.get_arguments(Config)

    # Create a file manager object
    cob_file_manager = FileManager()

    # Open list of files to process
    lst_apc_files = cob_file_manager.get_file_list()

    # Create a data processor object
    cob_data_processor = DataProcessor()

    # Create a user interface object to interact with user
    cob_user_interface = UserInterface()

    # Process files one at a time
    for str_input_file_name in lst_apc_files:

        # Create various file names
        str_input_file_name, str_output_file_name, str_enriched_file_name = cob_file_manager.create_file_names(
            str_input_file_name)

        # Read and clean data for one file
        lst_cleaned_data = cob_data_processor.collect_apc_data(str_input_file_name, args)

        # Save the file for further processing - Write cleaned data to file
        cob_data_processor.write_cleaned_data(str_output_file_name, lst_cleaned_data)

        # Run the German enrichment process and copy files
        cob_data_processor.run_enrichment_process(str_output_file_name)

        # Copy Bielfeld out file to institution directory
        cob_file_manager.copy_enrichment_out(str_enriched_file_name)

        # Backup master file
        cob_file_manager.backup_master_file(Config.STR_APC_SE_FILE)

        # Add new enriched data to master file
        cob_data_processor.add_new_data_to_master_file(str_enriched_file_name, cob_user_interface)

    # Report errors
    if len(cob_data_processor.lst_error_messages) > 0:
        print('WARNING: There were errors during processing. Error messages list:\n')
        for str_message in cob_data_processor.lst_error_messages:
            print(str_message)
    else:
        print('INFO: No errors during processing.\n')

# ======================================================================================================================


# ======================================================================================================================
class DataProcessor(object):
    """ Data cleaning and processing """

    # Keep a list of error messages
    lst_error_messages = []

    # ------------------------------------------------------------------------------------------------------------------
    def __init__(self):
        """ Set up basic data needed for processing """

        print('Info: Creating checkup file for processed DOIs')
        # self.mx_master_data = []
        self.lst_master_dois = []
        with open(Config.STR_APC_SE_FILE, 'rb') as csvfile:
            obj_csv_reader = csv.reader(csvfile, delimiter=',', quotechar='"')
            for lst_row in obj_csv_reader:
                if lst_row[3].strip():
                    self.lst_master_dois.append(lst_row[3].strip().lower())
        csvfile.close()

        # for str_doi in self.lst_master_dois:
        #     print str_doi

    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def normalise_publisher_names(self, lst_master_data):
        """ Final normalisation of publisher names after Crossref lookup names according to Bibsam principles """
        obj_publisher_normaliser = PublisherNormaliser()
        lst_cleaned_data = []
        str_publisher_name_normalised = ''
        for lst_row in lst_master_data:
            str_publisher_name = lst_row[5].strip()
            if lst_row[3].strip() and lst_row[3].strip().lower() != 'na':
                str_doi = lst_row[3].strip()
            else:
                str_doi = ''
            if str_publisher_name and str_doi:
                str_publisher_name_normalised = obj_publisher_normaliser.normalise(str_publisher_name, str_doi)
            if str_publisher_name_normalised and str_publisher_name_normalised != str_publisher_name:
                lst_row[5] = str_publisher_name_normalised
            lst_cleaned_data.append(lst_row)

        # Write new publisher names to file
        obj_publisher_normaliser.write_new_publisher_name_map()

        return lst_cleaned_data
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def run_enrichment_process(self, str_output_file_name):
        """ """

        # Run the DE process for enrichment as a shell command
        print('\nInfo: Running enrichment process on file {}'.format(str_output_file_name))
        if platform.system() == 'Windows':
            #locale not needed on this windows. "-l", "sv_SE.ISO8859-1" excluded. Call to Cmd need exact paths.
            call(["C:/Python27/python", "C:/Users/camlin/system/openapc-se/python/apc_csv_processing.py", str_output_file_name])
        elif platform.system() == 'Darwin':
            call(["../apc_csv_processing.py", "-l", "sv_SE.UTF-8", str_output_file_name])

    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def collect_apc_data(self, str_file_name, args):
        """ Method to collect data from institions suppliced CSV or TSV files """

        # A list for the cleaned data
        lst_cleaned_data = []

        #print '\nInfo: Processing file: {} \n==================================================== \n'.format(
        #    str_file_name)

        str_input_file_name = Config.STR_DATA_DIRECTORY + str_file_name
        lst_new_apc_data = self._clean_apc_data(str_input_file_name, args)

        for lst_row in lst_new_apc_data:
            lst_cleaned_data.append(lst_row)

        return lst_cleaned_data

    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def _clean_apc_data(self, str_input_file, args):
        """ Process APC file """

        # Create a publisher name normalising object
        obj_publisher_normaliser = PublisherNormaliser()

        # cleaned_content = []
        # error_messages = []

        enc = None  # CSV file encoding

        # Keep a list of processed DOI's to check for duplicates - what to do if found?
        lst_dois_processed = []

        if args.locale:
            norm = locale.normalize(args.locale)
            if norm != args.locale:
                print "locale '{}' not found, normalized to '{}'".format(args.locale, norm)
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
            if not row[2].strip():
                print('!Warning: No APC given for publication {}. Skipping entry.'.format(' - '.join(row)))
                continue

            # First non-empty row should be the header
            if has_header and row_num == 1:
                header = row
                cleaned_content.append(header)
                continue

            # Don't process lines who's DOIs are in the master file
            if row[3].strip() and row[3].strip().lower() != 'na':
                # Clean the DOI before continuing
                str_doi = self._clean_doi(row[3].strip())
                if str_doi.lower() in self.lst_master_dois:
                    print(u'Info: Skipping DOI present in master file: {}'. format(row[3].strip().lower()))
                    continue
            else:
                print('!Warning: No DOI found: {}'.format(' - '.join(row)))
                str_doi = ''

            current_row = []
            col_number = 0

            # Copy content of columns
            for csv_column in row:

                col_number += 1

                # Remove leading and trailing spaces
                csv_column = csv_column.strip()

                # Handling of APC column
                if col_number == 3:
                    # Clean monetary Euro column from spaces due to formatting
                    csv_column = ''.join(csv_column.split())
                    # Change commas to periods
                    csv_column = csv_column.replace(",", ".")

                # DOI handling
                if col_number == 4 and str_doi:
                    csv_column = str_doi
                    # Check for DOI duplicates
                    if str_doi not in lst_dois_processed:
                        lst_dois_processed.append(str_doi)
                    else:
                        sys.exit('!Error duplicate DOI {} - Org: {} - Year: {} '.format(str_doi, row[0], row[1]))

                # Handle hybrid flag true/false
                if col_number == 5:
                    if csv_column.lower() == u'sant':
                        csv_column = u'TRUE'
                    elif csv_column.lower() == u'falskt':
                        csv_column = u'FALSE'
                    elif csv_column == u'true':
                        csv_column = u'TRUE'
                    elif csv_column == u'false':
                        csv_column = u'FALSE'

                # Publisher name normalisation, use map or send DOI for CrossRef lookup
                if col_number == 6 and csv_column and str_doi:
                    str_publisher_name_normalised = obj_publisher_normaliser.normalise(csv_column, str_doi)
                    csv_column = str_publisher_name_normalised

                if csv_column != 'None':
                    current_row.append(csv_column)
                else:
                    current_row.append('')

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
        obj_publisher_normaliser.write_new_publisher_name_map()

        return cleaned_content

    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def _clean_doi(self, str_doi):
        """ Method to clean up garbled DOI strings """

        str_doi_original = str_doi

        # Remove any starting or trailing blanks
        str_doi = str_doi.strip()

        # Remove beginning and ending garbage
        str_doi = str_doi.strip('.,:;')

        # Don't try to clean empty DOI
        if not str_doi:
            return str_doi

        # Remove any non-ascii characters. Alternative (faster?): re.sub(r'[^\x00-\x7F]','', str_doi)
        str_doi = ''.join([i for i in str_doi if ord(i) < 128])
        str_doi = str_doi.replace(u'?', u'')
        str_doi = str_doi.replace(u'\u200b', u'')

        str_doi = str_doi.replace(u'1o.', u'10.', 1)
        str_doi = str_doi.replace(u'1O.', u'10.', 1)

        # Fix DOI beginning with '10/' instead of '10.'
        if str_doi.find(r'10/') == 0:
            print('Info: Error in DOI:              {}'.format(str_doi))
            str_doi = str_doi.replace(r'10/', r'10.', 1)
            print('Info: Cleaned DOI:               {}'.format(str_doi))
            self.doi_error = '{} -> {}'.format(str_doi_original, str_doi)

        # Fix DOI beginning with '10,' instead of '10.'
        if str_doi.find(r'10,') == 0:
            print('Info: Error in DOI:              {}'.format(str_doi))
            str_doi = str_doi.replace(r'10,', r'10.', 1)
            print('Info: Cleaned DOI:               {}'.format(str_doi))
            self.doi_error = '{} -> {}'.format(str_doi_original, str_doi)

        # Fix DOI beginning with '10-' instead of '10.'
        if str_doi.find(r'10-') == 0:
            print('Info: Error in DOI:              {}'.format(str_doi))
            str_doi = str_doi.replace(r'10-', r'10.', 1)
            print('Info: Cleaned DOI:               {}'.format(str_doi))
            self.doi_error = '{} -> {}'.format(str_doi_original, str_doi)

        # Fix DOI beginning with '19.' instead of '10.'
        if str_doi.find(r'19.') == 0:
            print('Info: Error in DOI:              {}'.format(str_doi))
            str_doi = str_doi.replace(r'19.', r'10.', 1)
            print('Info: Cleaned DOI:               {}'.format(str_doi))
            self.doi_error = '{} -> {}'.format(str_doi_original, str_doi)

        # Fix DOI beginning with '10.0' instead of '10.1'
        if str_doi.find(r'10.0') == 0:
            print('Info: Error in DOI:              {}'.format(str_doi))
            str_doi = str_doi.replace(r'10.', r'10.1', 1)
            print('Info: Cleaned DOI:               {}'.format(str_doi))
            self.doi_error = '{} -> {}'.format(str_doi_original, str_doi)

        # If no slash in DOI, it's probably too short
        if '/' not in str_doi:
            print('Info: Wrong format on DOI: {}'.format(str_doi))
            self.doi_error = str_doi
            return ''

        # Replace hard spaces with ordinary spaces to enable processing
        str_doi = str_doi.replace(u"\xc2\xa0", " ")

        # Make DOI lowercase for easier processing
        str_doi = str_doi.lower()

        # If the DOI starts with '0.' we can assume a lost 1
        if str_doi.find('0.') == 0:
            print('Info: DOI starting with 0.:      {}'.format(str_doi))
            str_doi = '1' + str_doi
            print('Info: Cleaned DOI:               {}'.format(str_doi))
            self.doi_error = '{} -> {}'.format(str_doi_original, str_doi)

        # Find the place of the starter string '10.'
        int_doi_start_pos = str_doi.find('10.')

        # If we don't have a '10.' at all, we have a problem, report and return empty string
        if int_doi_start_pos == -1:
            print('Info: DOI missing 10.:           {}'.format(str_doi))
            self.doi_error = str_doi
            str_doi = ''
            print('Info: Cleaned DOI:               {}'.format(str_doi))

        # If DOI don't start with '10.', we need cleaning of beginning of DOI
        if int_doi_start_pos > 0:
            print('Info: DOI not beginning with 10. : {}'.format(str_doi))
            str_doi = str_doi[int_doi_start_pos:]
            print('Info: Cleaned DOI:                 {}'.format(str_doi))
            self.doi_error = '{} -> {}'.format(str_doi_original, str_doi)

        # If we have blanks in the DOI, we have to clean it
        if ' ' in str_doi:
            print('Info: DOI containing spaces: {}'.format(str_doi))
            lst_doi_parts = str_doi.split()
            # If we have same DOI entered twice, use only the first
            if lst_doi_parts[0] == lst_doi_parts[1]:
                str_doi = lst_doi_parts[0]
            elif lst_doi_parts[1] == '.' or lst_doi_parts[1] == ',':
                # We have a single period as the last part - don't use it
                str_doi = lst_doi_parts[0]
            # elif lst_doi_parts[1] == self.publication_year:
            #     # Sometimes somehow year ends up here - don't use it
            #     str_doi = lst_doi_parts[0]
            else:
                str_doi = str_doi.replace(' ', '')

            print('Info: Cleaned DOI:           {}'.format(str_doi))
            self.doi_error = '{} -> {}'.format(str_doi_original, str_doi)

        return str_doi
    # ------------------------------------------------------------------------------------------------------------------


    # ------------------------------------------------------------------------------------------------------------------
    def write_cleaned_data(self, str_output_file_name, lst_cleaned_content):

        print 'INFO: Writing result to file {}'.format(str_output_file_name)

        with open(str_output_file_name, 'w') as out:

            for lst_line in lst_cleaned_content:
                if Config.BOOL_VERBOSE:
                    print lst_line
                if lst_line:
                    out.write(u'\t'.join(lst_line).encode("utf-8"))
                    out.write(u'\n')
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def add_new_data_to_master_file(self, str_enriched_file_name, cob_user_interface):
        """ Check how much of the newly enriched data that should be added """

        str_apc_se_file = Config.STR_APC_SE_FILE

        # Keep the header of the master file for separate writing to the final result
        lst_master_file_header = []

        # Read master file into a matrix and a dictionary of data
        dct_master_data = {}
        lst_master_dois = []
        with open(str_apc_se_file, 'rb') as csvfile:
            obj_csv_reader = csv.reader(csvfile, delimiter=',', quotechar='"')
            for lst_row in obj_csv_reader:
                str_doi = lst_row[3].lower().strip()
                str_key = ''
                if str_doi == 'doi':
                    lst_master_file_header = lst_row
                    continue
                # If we have a DOI
                if str_doi and str_doi.lower() != u'na':
                    str_key = str_doi
                # If no DOI is present
                else:
                    print('DOI missing {}'.format(lst_row))
                    # If article URL is present, use that as identifier (16)
                    if len(lst_row) > 16 and lst_row[16].strip():
                        str_key = lst_row[16].strip()
                    else:
                        # Create a new custom key from all fields for the entry in the dictionary
                        str_key = ''
                        for str_column in lst_row:
                            str_key + '.' + str_column
                    print(u'Info: Custom key: {}'.format(str_key))

                if str_key not in lst_master_dois and str_key not in dct_master_data.keys():
                    lst_master_dois.append(str_key)
                    dct_master_data[str_key] = lst_row
                else:
                    sys.exit('!Error: Duplicate DOI/Key in master file: {}'.format(str_key))

        csvfile.close()

        with open(str_enriched_file_name, 'rb') as csvfile:
            obj_csv_reader = csv.reader(csvfile, delimiter=',', quotechar='"')
            for lst_row in obj_csv_reader:

                str_doi = lst_row[3].lower().strip()

                # Skip header line
                if str_doi == 'doi':
                    continue

                # If we have a DOI
                if str_doi and str_doi.lower() != u'na':
                    str_key = str_doi
                # If no DOI is present
                else:
                    print('DOI missing {}'.format(lst_row))
                    # If article URL is present, use that as identifier (16)
                    if len(lst_row) > 16 and lst_row[16].strip():
                        str_key = lst_row[16].strip()
                    else:
                        # Create a new custom key from all fields for the entry in the dictionary
                        str_key = ''
                        for str_column in lst_row:
                            str_key + '.' + str_column
                    print(u'Info: Custom key: {}'.format(str_key))

                if str_key not in dct_master_data.keys():
                    dct_master_data[str_key] = lst_row
                    print(u'Info: Added new data {}'.format(u' '.join(lst_row)))
                    print(u'Info: Key: {}'.format(str_key))
                    continue
                else:
                    print('DOI/Key present {}'.format(str_key))
                    print('Present:\t{}'.format(dct_master_data[str_key]))
                    print('New:\t\t{}'.format(lst_row))
                    if lst_row == dct_master_data[str_key]:
                        print('info: Data are exactly the same. Skipping new record.')
                        continue
                    else:
                        print('Data differs. Choose item:')
                        lst_chosen_data = cob_user_interface.ask_user(dct_master_data[str_key], lst_row)
                        dct_master_data[str_key] = lst_chosen_data

                        # # If we don't have a DOI, we need to do some extra checking
                        # else:
                        #     # [Here 2017-08-04 ] #
                        #     print('DOI missing {}'.format(lst_row))
                        #     # Create a new custom key for the entry in the dictionary
                        #     str_key = lst_row[0] + '.' + lst_row[1] + '.' + lst_row[2] + '.' + lst_row[4] +
                        #  '.' + lst_row[5]
                        #     print('New:\t\t{}'.format(lst_row))
                        #     if str_key not in dct_master_data.keys():
                        #         dct_master_data[str_key] = lst_row
                        #         print(u'Info: Added new data {}'.format(u' '.join(lst_row)))
                        #         continue
                        #     else:
                        #         if lst_row == dct_master_data[str_key]:
                        #             print('New:\t\t{}'.format(lst_row))
                        #             print('Present:\t\t{}'.format(dct_master_data[str_key]))
                        #             print('info: Data are exactly the same. Skipping new record.')
                        #             continue
                        #         else:
                        #             print('Data differs. Adding new data item:')
                        #             print('New:\t\t{}'.format(lst_row))
                        #             print('Present:\t\t{}'.format(dct_master_data[str_doi]))
                        #             dct_master_data[str_key] = lst_row

        csvfile.close()

        # Make master dictionary to a list and sort it
        lst_master_data = [lst_row for str_doi, lst_row in dct_master_data.iteritems()]
        lst_master_data.sort()

        # Normalise names before writing to file
        lst_master_data = self.normalise_publisher_names(lst_master_data)

        # Write the new data to the master file
        print('\nInfo: Writing result to master file {}\n'.format(str_apc_se_file))
        with open(str_apc_se_file, 'wb') as csvfile:
            obj_csv_writer = csv.writer(csvfile, delimiter=',', quotechar='"')
            obj_csv_writer.writerow(lst_master_file_header)
            for lst_row in lst_master_data:
                obj_csv_writer.writerow(lst_row)
        csvfile.close()

    # ------------------------------------------------------------------------------------------------------------------

# ======================================================================================================================


# ======================================================================================================================
class FileManager(object):
    """ Class to keep file managing parameters and methods """

    # ------------------------------------------------------------------------------------------------------------------
    # @staticmethod
    def get_file_list(self):
        """ Fetch list of APC files to process
        :return: List of file names, including org directories
        """

        str_file_list_file = Config.STR_APC_FILE_LIST
        lst_apc_files = []
        try:
            fp_apc_files = open(str_file_list_file, 'r')
            print '\n--------------------------------------------------------------------------'
            print 'Info: Processing files:'
            for str_line in fp_apc_files:
                # Don't process if we have a comment (#) on the line
                if '#' in str_line:
                    continue
                lst_apc_files.append(str_line.strip())
                print str_line.strip()
            print '---------------------------------------------------------------------------\n'
        except IOError:
            print 'File list not found in: {}'.format(str_file_list_file)
            sys.exit()

        return lst_apc_files

    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def create_file_names(self, str_input_file_name):
        """ Create names for various files """

        # str_output_file_name = ''

        # Create an output file name
        if r'.csv' in str_input_file_name:
            str_output_file_name = Config.STR_DATA_DIRECTORY + str_input_file_name.replace(r'.csv', r'_cleaned.tsv')
        elif r'.tsv' in str_input_file_name:
            str_output_file_name = Config.STR_DATA_DIRECTORY + str_input_file_name.replace(r'.tsv', r'_cleaned.tsv')
        elif r'.xlsx' in str_input_file_name:
            str_output_file_name = Config.STR_DATA_DIRECTORY + str_input_file_name.replace(r'.xlsx', r'_cleaned.tsv')
            str_input_file_name = self.convert_excel_to_tsv(str_input_file_name)
        else:
            sys.exit('!Error: File {} is not in proper format for processing'.format(str_input_file_name))

        # Create a name for the final enriched file
        str_enriched_file_name = str_output_file_name.replace('_cleaned.tsv', '_enriched.csv')

        return str_input_file_name, str_output_file_name, str_enriched_file_name

    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def convert_excel_to_tsv(self, str_excel_file):
        """ If we have an Excel file as input, convert it to TSV for OA toolkit processing """

        # Make a TSV name to return to caller
        str_tsv_file = str_excel_file.replace(r'.xlsx', r'.tsv')

        str_excel_dir_file = Config.STR_DATA_DIRECTORY + str_excel_file
        str_tsv_dir_file = Config.STR_DATA_DIRECTORY + str_tsv_file
        # fp_tsv_file = open(str_tsv_dir_file, 'w')

        wb = load_workbook(filename=str_excel_dir_file, read_only=True)
        ws = wb.active  # ['Blad1']

        mx_converted_data = []

        for row in ws.rows:
            lst_row = []
            col_number = 0
            for cell in row:
                col_number += 1
                if col_number > 11:
                    break
                if cell.value != 'None':
                    lst_row.append(unicode(cell.value))
                else:
                    lst_row.append('')
            # print lst_row
            mx_converted_data.append(lst_row)

            # fp_tsv_file.write(u'\t'.join(lst_row).encode("utf-8"))
            # fp_tsv_file.write('\n')

        with open(str_tsv_dir_file, 'wb') as csvfile:
            obj_tsv_writer = csv.writer(csvfile, delimiter='\t', quotechar='"', quoting=csv.QUOTE_MINIMAL)
            for lst_row in mx_converted_data:
                obj_tsv_writer.writerow(lst_row)

        return str_tsv_file
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def backup_master_file(self, str_apc_se_file):
        """ Make a backup of master file before processing it
        :param str_apc_se_file:
        :return:
        """

        str_apc_se_backup = str_apc_se_file.replace(r'_se.csv', r'_se_backup.csv')  # ../../data/apc_se_backup.csv'
        print('\nINFO: Making a backup copy of master file: {}\n'.format(str_apc_se_backup))
        if platform.system() == 'Windows':
            copyfile(str_apc_se_file, str_apc_se_backup)
        elif platform.system() == 'Darwin':
            call(['cp', str_apc_se_file, str_apc_se_backup])

    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def copy_enrichment_out(self, str_enriched_file_name):
        """ Copy the output from python/se/out.csv to the organisation directory """

        print('\nCopying python/se/out.csv to {}'.format(str_enriched_file_name))
        copyfile('out.csv', str_enriched_file_name)
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def remove_cleaned_file(self, str_cleaned_file_name):
        """ Remove the temporary cleaned file
        :param str_cleaned_file_name:
        :return:
        """
        print('\nRemoving temporary file {}'.format(str_cleaned_file_name))
        call(["rm", str_cleaned_file_name])

    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def convert_excel_ssv_to_csv(self, str_apc_se_file):
        """ Convert Excel funny semicolon-separated CSV to a proper CSV """

        mx_master_data = []
        with open(str_apc_se_file, 'rb') as csvfile:
            obj_csv_reader = csv.reader(csvfile, delimiter=',', quotechar='"')
            for lst_row in obj_csv_reader:
                mx_master_data.append(lst_row)
        csvfile.close()

        with open(str_apc_se_file, 'wb') as fp_csv_file:
            obj_csv_witer = csv.writer(fp_csv_file, delimiter=',', quotechar='"')
            for lst_row in mx_master_data:
                obj_csv_witer.writerow(lst_row)

        fp_csv_file.close()

    # ------------------------------------------------------------------------------------------------------------------

# ======================================================================================================================


# ======================================================================================================================
class UserInterface(object):
    """ Class for methods for interacting with user """

    # ------------------------------------------------------------------------------------------------------------------
    def __init__(self):
        """ """
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def print_record_number(self, int_record_count):
        """ """
        print 'Record: {}'.format(int_record_count)
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def report(self, obj_input_data, obj_publication=None, str_reason=''):
        """ """
        print str_reason
        print obj_input_data.__unicode__()
        if obj_publication:
            print obj_publication.__unicode__()
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def report_and_wait(self, obj_input_data, obj_publication=None, str_reason=''):
        """ """
        print str_reason
        print obj_input_data.__unicode__()
        if obj_publication:
            print obj_publication.__unicode__()
        time.sleep(Config.INT_REPORT_WAIT)
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def report_and_stop(self, obj_input_data, obj_publication=None, str_reason=''):
        """ """
        print str_reason
        print obj_input_data.__unicode__()
        if obj_publication:
            print obj_publication.__unicode__()
        sys.exit('Stopping after report')
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def report_input(self, obj_output_data):
        """ Put input data into a dictionary and report it to user
        :param obj_output_data: Object with output data
        :return: Nothing
        """
        # Print neat divider
        self.print_divider(u'Input data')
        # print(lst_row)
        print(obj_output_data.__unicode__())
        # Print neat divider
        self.print_divider(u'End of record')
        print(u'')
        # return obj_output_data
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def ask_user(self, lst_present_publication, lst_new_publication):
        """ Ask opinion from user and return choice """

        print 'NOTE: Several name choices found. Please chose one alternative.'
        print 'Present:\t1) {}'.format(' '.join(lst_present_publication))
        print 'New:\t\t2) {}'.format(' '.join(lst_new_publication))
        str_choice = raw_input('Choose 1 or [2]:  ')
        if str_choice == '1':
            lst_chosen_data = lst_present_publication
        elif str_choice == '2':
            lst_chosen_data = lst_new_publication
        else:
            lst_chosen_data = lst_new_publication
        return lst_chosen_data
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    @staticmethod
    def print_divider(str_message, bool_space_before=False, bool_space_after=False):
        """ Print a nice divider
            :param str_message: Print a neat divider betweeen routines
            :param bool_space_before: Flag for space before
            :param bool_space_after: Flag for space after
            :return: Nothing
        """
        if bool_space_before:
            print
        print(u'---[{}]---------------------------------------------------------------------------'.format(str_message))
        if bool_space_after:
            print
    # ------------------------------------------------------------------------------------------------------------------

# ======================================================================================================================


# ======================================================================================================================
class PublisherNormaliser(object):
    """ Class to keep data and methods for publisher name normalisation """

    STR_PUBLISHER_NAME_MAP_FILE = Config.STR_DATA_DIRECTORY + 'publisher_name_map.tsv'

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
            # Look up in CrossRef - ToDo: Problem here if HTTP error instead of tuple returned
            dct_crossref_result = self.get_crossref_names(str_doi)
            if dct_crossref_result['error']:
                print('!ERROR: {}'.format(dct_crossref_result['error_reason']))
                print 'WARNING: No normalisation of name {}'.format(str_publisher_name_in)
                return str_publisher_name_in
            else:
                str_publisher_name_normalised = self.ask_user(str_publisher_name_in, dct_crossref_result)
            return str_publisher_name_normalised
        else:
            print 'WARNING: No normalisation of name {}'.format(str_publisher_name_in)
            return str_publisher_name_in
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def ask_user(self, str_publisher_name_in, dct_crossref_result):
        """ Ask opinion from user and return choice """
        print 'NOTE: Several name choices found. Please choose one alternative or enter new suggested name'
        print '1) {}'.format(str_publisher_name_in)
        print '2) {}'.format(dct_crossref_result['publisher'])
        print '3) {}'.format(dct_crossref_result['prefix'])
        print '4) Enter new preferred name'
        str_choice = raw_input('Choose [1] or enter new name:  ')
        if str_choice == '1':
            str_publisher_name_normalised = str_publisher_name_in.strip()
        elif str_choice == '2':
            str_publisher_name_normalised = dct_crossref_result['publisher'].strip()
        elif str_choice == '3':
            str_publisher_name_normalised = dct_crossref_result['prefix'].strip()
        elif str_choice:
            str_publisher_name_normalised = str_choice.strip()
        else:
            str_publisher_name_normalised = str_publisher_name_in
        # Add choice to mapping dictionary
        self.dct_publisher_name_map[str_publisher_name_in.lower()] = str_publisher_name_normalised
        return str_publisher_name_normalised
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def write_new_publisher_name_map(self):
        """ Write the new name map to file to remember for next processing """
        print('\nINFO: Updating publisher name normalisation file {}\n'.format(self.STR_PUBLISHER_NAME_MAP_FILE))
        fp_name_map_file = open(self.STR_PUBLISHER_NAME_MAP_FILE, 'w')
        for str_key in self.dct_publisher_name_map.keys():
            fp_name_map_file.write('{}\t{}\n'.format(str_key, self.dct_publisher_name_map[str_key]))
        fp_name_map_file.close()
    # ------------------------------------------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------------------------------------------
    def get_crossref_names(self, doi):
        """ Get Crossref info
            <crm-item name="publisher-name" type="string">Institute of Electrical ... (IEEE)</crm-item>
            <crm-item name="prefix-name" type="string">Institute of Electrical and Electronics Engineers</crm-item>
        """
        dct_crossref_lookup_result = dict(
            error = False,
            error_reason = '',
            publisher = '',
            prefix = '',
        )
        url = 'http://data.crossref.org/' + doi
        headers = {"Accept": "application/vnd.crossref.unixsd+xml"}
        req = urllib2.Request(url, None, headers)
        try:
            response = urllib2.urlopen(req)
            content_string = response.read()
            root = ElementTree.fromstring(content_string)
            prefix_name_result = root.findall(".//cr_qr:crm-item[@name='prefix-name']",
                                              {"cr_qr": "http://www.crossref.org/qrschema/3.0"})
            publisher_name_result = root.findall(".//cr_qr:crm-item[@name='publisher-name']",
                                                 {"cr_qr": "http://www.crossref.org/qrschema/3.0"})
            # return publisher_name_result[0].text, prefix_name_result[0].text
            dct_crossref_lookup_result['publisher'] = publisher_name_result[0].text
            dct_crossref_lookup_result['prefix'] = prefix_name_result[0].text
        except urllib2.HTTPError as httpe:
            dct_crossref_lookup_result['error'] = True
            code = str(httpe.getcode())
            dct_crossref_lookup_result['error_reason'] = "HTTPError: {} - {}".format(code, httpe.reason)
        except urllib2.URLError as urle:
            dct_crossref_lookup_result['error'] = True
            dct_crossref_lookup_result['error_reason'] = "URLError: {}".format(urle.reason)
        except ElementTree.ParseError as etpe:
            dct_crossref_lookup_result['error'] = True
            dct_crossref_lookup_result['error_reason'] = "ElementTree ParseError: {}".format(str(etpe))
        return dct_crossref_lookup_result
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
