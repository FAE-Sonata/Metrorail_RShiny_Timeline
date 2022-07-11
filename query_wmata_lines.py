# -*- coding: utf-8 -*-
"""
Spyder Editor

This is a temporary script file.
"""

import http.client, urllib.request, urllib.parse, urllib.error, base64
import json, pandas

def obtainHeaders(apiKey):
    headers = {
        # Request headers
        'api_key': apiKey,
    }
    return headers

def obtainStationOrder(headers, code1, code2):
    params = urllib.parse.urlencode({
        # Request parameters
        'FromStationCode': code1,
        'ToStationCode': code2,
    })
    
    try:
        conn = http.client.HTTPSConnection('api.wmata.com')
        conn.request("GET", "/Rail.svc/json/jPath?%s" % params, "{body}", headers)
        response = conn.getresponse()
        data = response.read()
        loaded = json.loads(data)
        lstStations = loaded['Path']
        return(pandas.DataFrame(lstStations))
        conn.close()
    except Exception as e:
        print("[Errno {0}] {1}".format(e.errno, e.strerror))

#wmataKey=input("Please enter your WMATA developer API key: ")
keyFile=open("wmata_api_key.txt","r")
wmataKey=keyFile.read()
keyFile.close()
headers=obtainHeaders(wmataKey)

# Glenmont, New Carrollton, Largo, Branch Ave, Huntington, Largo
terminiES=["B11", "D13", "G05", "F11", "C15", "G05"]
# Shady Grove, Vienna, Franconia, Greenbelt, Fort Totten, Wiehle
terminiWN=["A15", "K08", "J03", "E10", "E06", "N06"]
assert(len(terminiES) == len(terminiWN))

lstLines = list(map(lambda k: obtainStationOrder(headers, terminiES[k], terminiWN[k]),
               range(len(terminiES))))
dfFullLine = pandas.concat(lstLines)
dfFullLine = dfFullLine.replace([0], [None])
dfFullLine.to_csv('api_lines_in_travel_order.csv', sep=',', index=False)