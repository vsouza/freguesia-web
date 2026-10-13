defmodule FreguesiaWeb.Labels do
  @moduledoc """
  Translated labels for segments and categories (PRD §9 keys).

  Segment and category names live in the database under their keys. The screen
  shows these translated labels, so the copy goes through Gettext.
  """
  use Gettext, backend: FreguesiaWeb.Gettext

  # Order of the segment chips (PRD §5).
  @segment_order ~w(restaurants pharmacies grocery hardware pet)

  def segment_order, do: @segment_order

  def segment_label("restaurants"), do: gettext("Restaurants")
  def segment_label("pharmacies"), do: gettext("Pharmacies")
  def segment_label("grocery"), do: gettext("Grocery")
  def segment_label("hardware"), do: gettext("Hardware")
  def segment_label("pet"), do: gettext("Pet")
  def segment_label(_key), do: gettext("All")

  def category_label("pizza"), do: gettext("Pizza")
  def category_label("mineira"), do: gettext("Mineira")
  def category_label("burger"), do: gettext("Burger")
  def category_label("italian"), do: gettext("Italian")
  def category_label("japanese"), do: gettext("Japanese")
  def category_label("acai"), do: gettext("Açaí")
  def category_label(key), do: key
end
