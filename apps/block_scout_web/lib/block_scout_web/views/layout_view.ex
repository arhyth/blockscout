defmodule BlockScoutWeb.LayoutView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.SocialMedia

  def network_icon_partial do
    Keyword.get(application_config(), :network_icon) || "_network_icon.html"
  end

  def logo do
    Keyword.get(application_config(), :logo) || "/images/poa_logo.svg"
  end

  def subnetwork_title do
    Keyword.get(application_config(), :subnetwork) || "Sokol Testnet"
  end

  def app_title do
    network_title = Keyword.get(application_config(), :network) || "POA"

    gettext("%{subnetwork} %{network} Explorer", subnetwork: subnetwork_title(), network: network_title)
  end

  defp application_config do
    Application.get_env(:block_scout_web, BlockScoutWeb.Chain)
  end

  def configured_social_media_services do
    SocialMedia.links()
  end
end
