defmodule Lifx.Mixfile do
  use Mix.Project

  def project do
    [app: :lifx,
     version: "0.1.4",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     deps: deps()]
  end

  def application do
    [
        applications: [:logger, :cowboy, :poison],
        mod: {Lifx, []},
        env: [tcp_server: true, tcp_port: 8800]
    ]
  end

  def description do
      """
      A Client for Lifx LAN API
      """
  end

  def package do
    [
      name: :lifx,
      files: ["lib", "priv", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Christopher Steven Coté"],
      licenses: ["MIT License"],
      links: %{"GitHub" => "https://github.com/NationalAssociationOfRealtors/lifx",
          "Docs" => "https://github.com/NationalAssociationOfRealtors/lifx"}
    ]
  end

  def description do
      """
      A Client for Lifx LAN API
      """
  end

  def package do
    [
      name: :lifx,
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Christopher Steven Coté"],
      licenses: ["Apache License 2.0"],
      links: %{"GitHub" => "https://github.com/NationalAssociationOfRealtors/lifx",
          "Docs" => "https://github.com/NationalAssociationOfRealtors/lifx"}
    ]
  end

  defp deps do
    [
        {:cowboy, "~> 1.0"},
        {:poison, "~> 2.1"},
        {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
