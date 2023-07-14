# Icinga for Windows - NEP module

Reminder: per usarlo copiare nei moduli e poi

```
Publish-IcingaForWindowsComponent nep
Publish-IcingaPluginConfiguration nep
```

NB: se la porta tcp sql non è standard (1433) va specificata, se non siamo sulla macchina dell'istanza specificare sqlhost, il modulo icinga sql non riesco a farlo connettere in altro modo, 
non dimenticare mai Integratedsecurity switch!!
esempi tutti su macchina ax2012r3a

testare con 
```
icinga { Invoke-IcingaNepMSSQLAgentRunningJobs -IntegratedSecurity -SqlPort 63782 .... }
```

## Invoke-IcingaNepMSSQLAgentRunningJobs

### Modalità *All Jobs* 

monitoraggio di tutti i jobs con soglie in secondi di 1800, 3600 (30 m, 1h)  

```
Invoke-IcingaNepMSSQLAgentRunningJobs -SecondsDurationWarning 1800 -SecondsDurationCritical 3600
```

risultato espone la durata del job che è in esecuzione da più tempo, se nessun job è in esecuzione la durata è 0
```
[OK] MSSQL Agent Running Jobs Status
| 'duration'=190s;1800;3600
```

Questa modalità è sconsigliata, come vediamo dalla seguente tabella ci sono jobs per cui è completamente naturale durare alcune ore mentre altri devono durare pochi minuti

### Modalità *single job*: 

monitoraggio del job *syspolicy_purge_history* con soglie in secondi di 1800, 3600 (30 m, 1h)  

```
Invoke-IcingaNepMSSQLAgentRunningJobs -JobName 'syspolicy_purge_history' -SecondsDurationWarning 1800 -SecondsDurationCritical 3600
```

risultato include il nome del job nella description, la durata è quella del singolo job, se il job non è in esecuzione la durata è 0
```
[OK] MSSQL Agent Running Job syspolicy_purge_history Status
| 'duration'=17s;1800;3600
```



`
