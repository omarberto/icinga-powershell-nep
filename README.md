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

### Modalità *All jobs* 

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

### Modalità *Single job*: 

monitoraggio del job *syspolicy_purge_history* con soglie in secondi di 1800, 3600 (30 m, 1h)  

```
Invoke-IcingaNepMSSQLAgentRunningJobs -JobName 'syspolicy_purge_history' -SecondsDurationWarning 1800 -SecondsDurationCritical 3600
```

risultato include il nome del job nella description, la durata è quella del singolo job, se il job non è in esecuzione la durata è 0
```
[OK] MSSQL Agent Running Job syspolicy_purge_history Status
| 'duration'=17s;1800;3600
```

## Invoke-IcingaNepMSSQLTempDBFreeSpace

Il check è fatto sul totale dei files di tipo ROWS, visto che non è assolutamene critico il fatto che il singolo file si riempia

Nel caso ci fossero installazioni particolari con i files mescolati su dischi diversi, usare altri checks

Nota: nessun monitoraggio al momento del fatto che i singoli files abbiano la stessa dimensione (raccomandato)

Premessa: come si vedrà il check dovrà tenere conto delle impostazioni autogrowth e max_size 

### Autogrowth with unlimited size files

Se autogrowth è attivo e non c'è limite alla dimensione dei files, vanno usati SizeMBWarning e SizeMBCritical intesi come dimensioni massime dei files (inteso come somma totale), i perfdata poi ci daranno misura di quando abbiamo un growth

Esempio con soglie a 1GB e 2GB

```
Invoke-IcingaNepMSSQLTempDBFreeSpace -SizeMBWarning 1024  -SizeMBCritical 2048
```

perfdata indicano percentuale di spazio libero per singolo file rispetto alla dimensione attuale
```
[OK] MSSQL TempDB Free Space
 'temp2'=99.26%;;;0;100 'temp3'=99.27%;;;0;100 'temp4'=99.29%;;;0;100 'tempdev'=98.75%;;;0;100
```

se usaimo i valori percentuali abbiamo un warning permanente come nell'esempio
```
Invoke-IcingaNepMSSQLTempDBFreeSpace -AvailablePercentageWarning 20 -AvailablePercentageCritical 10
[WARNING] MSSQL TempDB Free Space [WARNING] Using Percentage Thresholds leads meaningless warnings and errors with files with no size limits: use fixed threshol
d instead (True)
\_ [WARNING] Using Percentage Thresholds leads meaningless warnings and errors with files with no size limits: use fixed threshold instead: True is matching thr
eshold True
| 'temp2'=99.63%;;;0;100 'temp3'=99.63%;;;0;100 'temp4'=99.65%;;;0;100 'tempdev'=99.38%;;;0;100
```

### Autogrowth with limited size files

Se autogrowth è attivo e files hanno dimensione massima meglio usare i valori in percentuale (se si usano soglie in MB e il totale è più grande del limite impostato sull'istanza avremo un errore)

```
Invoke-IcingaNepMSSQLTempDBFreeSpace -AvailablePercentageWarning 20 -AvailablePercentageCritical 10
```

perfdata indicano percentuale di spazio libero per singolo file rispetto alla dimensione massima
```
[OK] MSSQL TempDB Free Space
 'temp2'=99.26%;;;0;100 'temp3'=99.27%;;;0;100 'temp4'=99.29%;;;0;100 'tempdev'=98.75%;;;0;100
```

### Fixed size files

Se files hanno dimensione fissata meglio usare i valori in percentuale (se si usano soglie in MB e il totale è più grande della dimensione dei files avremo un errore)
Nota: nel caso assolutamente anomalo che la dimensione dei files sia maggiore della dimensione massima impostata avremo un errore

```
Invoke-IcingaNepMSSQLTempDBFreeSpace -AvailablePercentageWarning 20 -AvailablePercentageCritical 10
```

perfdata indicano percentuale di spazio libero per singolo file rispetto alla dimensione attuale
```
[OK] MSSQL TempDB Free Space
 'temp2'=99.26%;;;0;100 'temp3'=99.27%;;;0;100 'temp4'=99.29%;;;0;100 'tempdev'=98.75%;;;0;100
```

## Invoke-IcingaNepMSSQLTransactionLogFreeSpace

Nota: se omesso il database monitorato è master

### Autogrowth with unlimited size files

Se autogrowth è attivo e non c'è limite alla dimensione del file, vanno usati SizeMBWarning e SizeMBCritical intesi come dimensioni massime, i perfdata poi ci daranno misura di quando abbiamo un growth
se invece usaimo i valori percentuali abbiamo un warning permanente

Esempio con soglie a 1GB e 2GB

```
Invoke-IcingaNepMSSQLTransactionLogFreeSpace -SQLDatabase 'AXDB' -SizeMBWarning 1024  -SizeMBCritical 2048
```

perfdata indicano percentuale di spazio libero rispetto alla dimensione attuale
```
[OK] MSSQL AXDB Transaction Log Free Space
| 'templog'=99.26%;;;0;100
```

### Autogrowth with limited size files

Se autogrowth è attivo e file ha dimensione massima meglio usare i valori in percentuale (se si usano soglie in MB e il valore è più grande del limite impostato sull'istanza avremo un errore)

```
Invoke-IcingaNepMSSQLTransactionLogFreeSpace -SQLDatabase 'AXDB' -AvailablePercentageWarning 20 -AvailablePercentageCritical 10
```

perfdata indicano percentuale di spazio libero rispetto alla dimensione massima
```
[OK] MSSQL AXDB Transaction Log Free Space
| 'templog'=99.26%;;;0;100
```

### Fixed size files

Se file ha dimensione fissata meglio usare i valori in percentuale (se si usano soglie in MB e il valore è più grande della dimensione del file avremo un errore)
Nota: nel caso assolutamente anomalo che la dimensione del file sia maggiore della dimensione massima impostata avremo un errore

```
Invoke-IcingaNepMSSQLTransactionLogFreeSpace -SQLDatabase 'AXDB' -AvailablePercentageWarning 20 -AvailablePercentageCritical 10
```

perfdata indicano percentuale di spazio libero rispetto alla dimensione attuale
```
[OK] MSSQL AXDB Transaction Log Free Space
| 'templog'=99.26%;;;0;100
```
