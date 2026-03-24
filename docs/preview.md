# Preview-Berechnung

Das zwoelfte Inkrement fuehrt die erste fachliche Preview-Berechnung fuer primaere SMTP-Adresse und Aliasliste ein.

## Modul

- `src/Engine/ProxyAddressManager.Preview.psm1`

## Oeffentliche Funktionen

- `New-PamRecipientPreview`

## Verhalten

- Die primaere Adresse wird aus `primaryAddressTemplate` und `domainRules.primaryDomain` berechnet.
- Alias-Adressen werden aus `aliasTemplates` und `domainRules.aliasDomains` erzeugt.
- Wenn ein Template bereits eine vollstaendige Adresse mit `@` liefert, wird keine Domain mehr angehaengt.
- Local-Parts ohne `@` laufen durch die vorhandene Normalisierungspipeline.
- SMTP-Werte werden innerhalb des Ergebnisses dedupliziert.
- Ein Alias, der der primaeren Adresse entspricht, wird verworfen.
- Vorhandene Nicht-SMTP-Werte wie `X500:` oder `SIP:` bleiben separat im Preview-Modell erhalten.

## Rueckgabe von `New-PamRecipientPreview`

- `Identity`
- `AppliedRule`
- `CurrentMail`
- `ProposedMail`
- `CurrentProxyAddresses`
- `ProposedProxyAddresses`
- `PreservedNonSmtpProxyAddresses`
- `Changes`
- `Diff`
- `Warnings`

## Ziel fuer die naechsten Inkremente

- Inkrement 13 kann jetzt das eigentliche Ist/Soll-Diff fuer `mail` und `proxyAddresses` modellieren.
- Damit rueckt der erste wirklich brauchbare End-to-End-Read-only-Test mit echten Regeln und AD-Daten greifbar nah.
