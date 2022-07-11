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

def obtainStations(headers, lineCode):
    params = urllib.parse.urlencode({
        # Request parameters
        'LineCode': lineCode,
    })
    
    try:
        conn = http.client.HTTPSConnection('api.wmata.com')
        conn.request("GET", "/Rail.svc/json/jStations?%s" % params, "{body}", headers)
        response = conn.getresponse()
        data = response.read()
        loaded = json.loads(data.decode())
        conn.close()
        resDict = loaded['Stations']
        for st in resDict:
            try:
                del st['Address']
            except KeyError as ke:
                print("No such key: '%s'" & ke.message)
#        resDict = loaded['stations']
#        try:
#            del resDict['address']
#        except KeyError as ke:
#            print("No such key: '%s'" & ke.message)
        res = pandas.DataFrame.from_dict(resDict)
#        pandas.Series([lineCode for k in range(len(resDict))])
        res['queriedLine'] = lineCode
        return res
    except Exception as e:
        print("[Errno {0}] {1}".format(e.errno, e.strerror))
        return None

#wmataKey=input("Please enter your WMATA developer API key: ")
keyFile=open("wmata_api_key.txt","r")
wmataKey=keyFile.read()
keyFile.close()
headers=obtainHeaders(wmataKey)
#tmp=obtainStations(headers, "RD")
#tmpJson=json.loads(tmp.decode())
lineCodes=["RD", "OR", "BL", "GR", "YL", "SV"]
fullStationList=list(map(lambda s: obtainStations(headers, s), lineCodes))
#dictFullStation=dict(pandas.concat(fullStationList))
dfFullStation=pandas.concat(fullStationList)
dfFullStation.to_csv('api_stations.csv', sep=',', index=False)
#with open('api_stations.csv', 'w', newline='') as f:
#    writer = csv.writer(f)
#    writer.writerows(dfFullStation)