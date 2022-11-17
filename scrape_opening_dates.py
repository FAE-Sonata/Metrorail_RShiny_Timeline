# -*- coding: utf-8 -*-
import re, requests
from bs4 import BeautifulSoup # +lxml to requirements.txt
import pandas as pd

ESCAPES = ''.join([chr(char) for char in range(1, 32)])
TRANSLATOR = str.maketrans('', '', ESCAPES)
RE_UNION = re.compile("^Union")
RE_LEVEL = re.compile("(upp|low)er level")
def is_opening_table(table):
    re_opened = re.compile("^Opened")
    return any([re.match(re_opened, header.text) is not None for header in
                table.findChildren("th", recursive=True)])

def get_opening_table(url):
    page = requests.get(url)
    soup_from_page = BeautifulSoup(page.text, 'lxml') #'html.parser'
    sortables = soup_from_page.find_all('table', attrs={"class": "wikitable sortable"})
    res = [table for table in sortables if is_opening_table(table)]
    return res[0]

def remove_escape(s):
    # https://stackoverflow.com/a/8115378
    return s.translate(TRANSLATOR)

def process_row(row):
    entries = row.findChildren("td")
    station_link = entries[0].find_all('a', href=True, title=True)
    wikilink = station_link[0]['title']
    table_text = entries[0].text
    name = "Union Station" if re.match(RE_UNION, wikilink) else wikilink[:(
        wikilink.find(' station'))]
    if re.findall(RE_LEVEL, table_text):
        idx_level = table_text.find("level")
        level = table_text[(idx_level - len(" level")):(idx_level - 1)]
        name = f"{name} ({level})"
    line_titles = [line['title'] for line in entries[1].find_all('a',href=True)]
    lines = ",".join([s[:(s.find(" Line"))] for s in line_titles])
    opening_mdy = remove_escape(entries[-1].text)
    return (name, lines, opening_mdy)

def scrape(url):
    opening_table = get_opening_table(url)
    body = opening_table.findChildren("tbody")
    rows = body[0].findChildren("tr")
    # first row is somehow the header
    station_info = [process_row(row) for row in rows[1:]]
    res = pd.DataFrame({'station': [x[0] for x in station_info],
                        'lines': [x[1] for x in station_info],
                        'opening': [x[2] for x in station_info]})
    return res

df_table = scrape("https://en.wikipedia.org/w/index.php?title=List_of_Washington_Metro_stations&oldid=1122154339")
df_table.to_csv('station_opening_dates_scraped.csv', sep=',', index=False)