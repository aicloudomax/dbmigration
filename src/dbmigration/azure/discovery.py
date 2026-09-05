"""Enumerate Azure subscriptions and their database servers/databases.

Uses ``DefaultAzureCredential`` so it works with ``az login``, a service
principal (env vars), or a managed identity. Discovery only lists resources; it
never reads data — that is the extractors' job.
"""

from __future__ import annotations

from dataclasses import dataclass

from ..model import SourceKind


@dataclass
class DiscoveredDatabase:
    subscription_id: str
    subscription_name: str
    resource_group: str
    server_name: str      # e.g. myserver.database.windows.net
    server_host: str      # connectable host
    kind: SourceKind
    database: str


def _credential():
    from azure.identity import DefaultAzureCredential

    return DefaultAzureCredential(exclude_interactive_browser_credential=True)


def list_subscriptions(wanted: list[str] | None = None) -> list[tuple[str, str]]:
    """Return (subscription_id, display_name) pairs.

    If *wanted* is non-empty, only subscriptions whose id or name is in the list
    are returned.
    """
    from azure.mgmt.resource import SubscriptionClient

    client = SubscriptionClient(_credential())
    subs: list[tuple[str, str]] = []
    for sub in client.subscriptions.list():
        sid = sub.subscription_id
        name = sub.display_name or sid
        if wanted and sid not in wanted and name not in wanted:
            continue
        subs.append((sid, name))
    return subs


def discover_sql_databases(subscription_id: str, subscription_name: str) -> list[DiscoveredDatabase]:
    """List all Azure SQL databases across every server in a subscription."""
    from azure.mgmt.sql import SqlManagementClient

    client = SqlManagementClient(_credential(), subscription_id)
    out: list[DiscoveredDatabase] = []
    for server in client.servers.list():
        rg = _resource_group_from_id(server.id)
        host = server.fully_qualified_domain_name or f"{server.name}.database.windows.net"
        for db in client.databases.list_by_server(rg, server.name):
            if (db.name or "").lower() == "master":
                continue
            out.append(
                DiscoveredDatabase(
                    subscription_id=subscription_id,
                    subscription_name=subscription_name,
                    resource_group=rg,
                    server_name=server.name,
                    server_host=host,
                    kind=SourceKind.AZURE_SQL,
                    database=db.name,
                )
            )
    return out


def discover_postgres_databases(
    subscription_id: str, subscription_name: str
) -> list[DiscoveredDatabase]:
    """List all databases on Azure PostgreSQL Flexible Servers in a subscription."""
    from azure.mgmt.rdbms.postgresql_flexibleservers import PostgreSQLManagementClient

    client = PostgreSQLManagementClient(_credential(), subscription_id)
    out: list[DiscoveredDatabase] = []
    for server in client.servers.list():
        rg = _resource_group_from_id(server.id)
        host = server.fully_qualified_domain_name or f"{server.name}.postgres.database.azure.com"
        for db in client.databases.list_by_server(rg, server.name):
            out.append(
                DiscoveredDatabase(
                    subscription_id=subscription_id,
                    subscription_name=subscription_name,
                    resource_group=rg,
                    server_name=server.name,
                    server_host=host,
                    kind=SourceKind.AZURE_POSTGRES,
                    database=db.name,
                )
            )
    return out


def _resource_group_from_id(resource_id: str) -> str:
    """Extract the resource group name from an ARM resource id."""
    parts = resource_id.split("/")
    try:
        return parts[parts.index("resourceGroups") + 1]
    except (ValueError, IndexError):
        return ""
