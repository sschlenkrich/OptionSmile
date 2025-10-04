
import logging
import os
import sys
import warnings

import pandas as pd


if __name__ == '__main__':
    logging.basicConfig(
        level=logging.INFO,
        format="%(levelname)s | %(asctime)s | %(message)s"
    )
    logging.info("Start script " + os.path.basename(__file__) + ".")
    #
    dirname = os.path.dirname(__file__)
    modules_path = os.path.join(dirname, "../python/")
    sys.path.append(modules_path)
    import data
    import smiledata
    import dateutils
    #
    warnings.simplefilter(action='ignore', category=UserWarning)  # suppress pandas sql warning
    #
    symbols_file_name = os.path.join(dirname, "../data/SP500.csv")
    logging.info("Read symbols from file " + os.path.basename(symbols_file_name) + ".")
    symbols = pd.read_csv(symbols_file_name, sep=";")["Symbol"]
    logging.info("Find %d symbols" % symbols.shape[0] + ".")
    #
    logging.info("Initialise database connections.")
    cons = data.initialise()
    for key in cons:
        logging.info("Connection " + key + " is " + str(cons[key].db) + ".")
    #
    logging.info("Update rates database.")
    messages = data.update_rates()
    for m in messages:
        logging.info(m)
    logging.info("Update stocks database.")
    messages = data.update_stocks()
    for m in messages:
        logging.info(m)
    logging.info("Update options database.")
    messages = data.update_options()
    for m in messages:
        logging.info(m)
    logging.info("Update volatilities database.")
    message = data.pull_volatilities()
    logging.info(message)    
    #
    logging.info("Read queue from databases, this takes few minutes...")
    queue = data.queue(symbols)
    n_entries = queue.shape[0]
    first_date = dateutils.iso_date(queue.iloc[0]["date"])
    last_date = dateutils.iso_date(queue.iloc[-1]["date"])
    logging.info("Find %d entries in queue, start date %s, end date %s." % (n_entries, first_date, last_date))
    logging.info("Start iterating queue...")
    last_date = first_date
    for _, elem in queue.iterrows():
        try:
            symbol = elem["act_symbol"]
            date = dateutils.iso_date(elem["date"])
            #
            if date != last_date:
                logging.info("Commit and push data for %s." % last_date)
                messages = data.push_volatilities(last_date)
                for m in messages:
                    logging.info(m)
            last_date = date
            #
            logging.info("Process date %s, symbol %s." % (date, symbol))
            try:
                d = smiledata.store_smile_data(symbol=symbol, date=date)
                logging.info(d["message"])
            except Exception as e:
                logging.warning(("UNEXPECTED ERROR. Failed processing date %s, symbol %s. " % (date, symbol)) + str(e))
            #
        except KeyboardInterrupt:
            logging.info("Interrupt queue iteration.")
            break
    #
    logging.info("Commit and push data for %s." % last_date)
    messages = data.push_volatilities(last_date)
    for m in messages:
        logging.info(m)
    logging.info("Finish script " + os.path.basename(__file__) + ".")
