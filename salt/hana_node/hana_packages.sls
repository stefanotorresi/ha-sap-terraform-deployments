python-shaptools:
  pkg.installed:
    - fromrepo: saphana
    - require:
      - add-saphana-repo

salt-saphana:
  pkg.installed:
    - fromrepo: saphana
    - require:
      - add-saphana-repo

saphanabootstrap-formula:
  pkg.installed:
    - fromrepo: saphana
    - require:
      - add-saphana-repo

#required packages to install SAP HANA, maybe they are already installed in the
#used SLES4SAP distros
numactl:
  pkg.installed

libltdl7:
  pkg.installed

#this package should be installed in saphanabootstrap-formula
netcat-openbsd:
  pkg.installed